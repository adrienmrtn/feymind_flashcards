package com.micabo.app.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.util.Base64
import androidx.annotation.StringRes
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.micabo.app.R
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.encryption.InvalidPasswordException
import com.tom_roush.pdfbox.text.PDFTextStripper
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.zip.ZipInputStream
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * **Un support lu sur le téléphone**, prêt à partir dans une leçon (`ImportedDocument` sur
 * iPhone) : son texte, quelques pages en JPEG pour la passe visuelle du serveur, son nom.
 */
data class ImportedDocument(
    val text: String,
    /** Les pages, en `data:image/jpeg;base64,…` : le format que `generate-lesson` accepte. */
    val images: List<String>,
    val name: String,
    /** pdf, docx, photo, youtube : la valeur que le serveur lit (`LessonSourceKind`). */
    val source: String,
) {
    val isUsable: Boolean get() = text.trim().length >= 40 || images.isNotEmpty()
}

/** Un support illisible : la phrase à montrer sur sa pastille. */
class ImportException(@StringRes val messageRes: Int) : Exception()

/** Les réglages de lecture, les mêmes que sur iPhone (`PDFImportService.Options`, `ImagePrep`). */
private object ImportLimits {
    const val IMAGE_PAGES = 6
    const val IMAGE_DIMENSION = 1400
    const val JPEG_QUALITY = 55
    /** Les pages lues par l'OCR quand le fichier n'a presque pas de texte (`OnDeviceOCR.pageLimit`). */
    const val OCR_PAGES = 40
    const val OCR_DIMENSION = 1800
    /** En dessous, un PDF est un scan : on le lit à l'OCR. */
    const val SCAN_TEXT = 200
}

/** Le nom du fichier, sans son extension. */
fun displayName(context: Context, uri: Uri): String? = runCatching {
    context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
        if (cursor.moveToFirst()) cursor.getString(0) else null
    }
}.getOrNull()?.substringBeforeLast('.')?.takeIf { it.isNotBlank() }

/** Les images : réduites, en JPEG, en base64. */
object ImagePrep {
    fun dataUrl(bitmap: Bitmap, maxDimension: Int = ImportLimits.IMAGE_DIMENSION, quality: Int = ImportLimits.JPEG_QUALITY): String {
        val scaled = scaled(bitmap, maxDimension)
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, quality, out)
        if (scaled !== bitmap) scaled.recycle()
        return "data:image/jpeg;base64," + Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    }

    fun scaled(bitmap: Bitmap, maxDimension: Int): Bitmap {
        val longest = max(bitmap.width, bitmap.height)
        if (longest <= maxDimension) return bitmap
        val scale = maxDimension.toFloat() / longest
        return Bitmap.createScaledBitmap(bitmap, (bitmap.width * scale).roundToInt().coerceAtLeast(1), (bitmap.height * scale).roundToInt().coerceAtLeast(1), true)
    }

    /** Une photo de la galerie ou du scanner, à l'endroit, et pas plus grande qu'il ne faut. */
    fun decode(context: Context, uri: Uri, maxDimension: Int): Bitmap? = runCatching {
        if (Build.VERSION.SDK_INT >= 28) {
            val source = ImageDecoder.createSource(context.contentResolver, uri)
            ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                val longest = max(info.size.width, info.size.height)
                if (longest > maxDimension) {
                    val scale = maxDimension.toFloat() / longest
                    decoder.setTargetSize((info.size.width * scale).roundToInt().coerceAtLeast(1), (info.size.height * scale).roundToInt().coerceAtLeast(1))
                }
            }
        } else {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            var sample = 1
            while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxDimension) sample *= 2
            val decoded = context.contentResolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
            } ?: return@runCatching null
            val orientation = context.contentResolver.openInputStream(uri)?.use {
                ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            } ?: ExifInterface.ORIENTATION_NORMAL
            val degrees = when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
            val upright = if (degrees == 0f) decoded else {
                Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, Matrix().apply { postRotate(degrees) }, true)
            }
            scaled(upright, maxDimension)
        }
    }.getOrNull()
}

/**
 * **L'OCR sur le téléphone**, comme Vision sur iPhone : ML Kit, par les services Google Play
 * (rien à embarquer dans l'app), gratuit et hors ligne. Il lit l'alphabet latin ; pour le
 * reste, les pages partent en images et le serveur les lit.
 */
object OnDeviceOcr {
    private val recognizer by lazy { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }

    /** Une page illisible rend un texte vide ; un support retiré arrête la lecture. */
    suspend fun read(bitmap: Bitmap): String = try {
        recognizer.process(InputImage.fromBitmap(bitmap, 0)).await().textBlocks.joinToString("\n\n") { it.text }
    } catch (cancel: CancellationException) {
        throw cancel
    } catch (error: Exception) {
        ""
    }

    suspend fun read(bitmaps: List<Bitmap>): String =
        bitmaps.map { read(it) }.filter { it.isNotBlank() }.joinToString("\n\n")
}

/** Le texte lu, nettoyé comme sur iPhone (`TextSanitizer.normalizeExtractedText`). */
private fun normalize(text: String): String = text
    .replace("\r\n", "\n")
    .replace(Regex("-\n(?=\\p{Ll})"), "")
    .replace(Regex("[ \\t\\u00A0]+"), " ")
    .replace(Regex(" *\n *"), "\n")
    .replace(Regex("\n{3,}"), "\n\n")
    .trim()

/** Les pages à montrer au modèle : toutes s'il y en a peu, sinon réparties dans le document. */
private fun sampledPages(count: Int, limit: Int): List<Int> {
    if (count <= limit) return (0 until count).toList()
    val stride = (count - 1).toDouble() / (limit - 1)
    return (0 until limit).map { (it * stride).roundToInt() }.distinct()
}

/**
 * **Un PDF** (`PDFImportService`) : le texte du fichier par PDFBox ; s'il n'y en a presque
 * pas (un scan), l'OCR lit les pages. Quelques pages rendues en JPEG partent en plus, pour les
 * schémas et les formules.
 */
object PdfImport {
    suspend fun read(context: Context, uri: Uri): ImportedDocument = withContext(Dispatchers.IO) {
        val name = displayName(context, uri) ?: "PDF"
        // Une copie locale d'abord : un fournisseur dans le nuage rend souvent un tube, que
        // PdfRenderer ne sait pas parcourir, et le fichier se lit deux fois (PDFBox, puis le rendu).
        val file = copyToCache(context, uri) ?: throw ImportException(R.string.ios_pdf_unreadable)
        try {
            var text = embeddedText(context, file)
            val descriptor = runCatching { ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY) }.getOrNull()
                ?: throw ImportException(R.string.ios_pdf_unreadable)
            val renderer = try {
                PdfRenderer(descriptor)
            } catch (error: Exception) {
                descriptor.close()
                // Le texte lu par PDFBox suffit à faire une leçon, même sans les pages en images.
                if (text.length >= ImportLimits.SCAN_TEXT) {
                    return@withContext ImportedDocument(text = text, images = emptyList(), name = name, source = "pdf")
                }
                throw ImportException(if (error is SecurityException) R.string.ios_pdf_protected else R.string.ios_pdf_unreadable)
            }
            try {
                val count = renderer.pageCount
                if (count == 0) throw ImportException(R.string.ios_pdf_empty)
                val images = sampledPages(count, ImportLimits.IMAGE_PAGES).mapNotNull { index ->
                    ensureActive()
                    render(renderer, index, ImportLimits.IMAGE_DIMENSION)?.let { page ->
                        ImagePrep.dataUrl(page).also { page.recycle() }
                    }
                }
                if (text.length < ImportLimits.SCAN_TEXT) {
                    val pages = (0 until minOf(count, ImportLimits.OCR_PAGES))
                    val read = StringBuilder()
                    for (index in pages) {
                        ensureActive()
                        val page = render(renderer, index, ImportLimits.OCR_DIMENSION) ?: continue
                        val pageText = OnDeviceOcr.read(page)
                        page.recycle()
                        if (pageText.isNotBlank()) read.append(pageText).append("\n\n")
                    }
                    val ocr = normalize(read.toString())
                    if (ocr.length > text.length) text = ocr
                }
                if (text.isBlank() && images.isEmpty()) throw ImportException(R.string.ios_pdf_empty)
                ImportedDocument(text = text, images = images, name = name, source = "pdf")
            } finally {
                renderer.close()
                descriptor.close()
            }
        } finally {
            file.delete()
        }
    }

    /** Le PDF recopié dans le cache de l'app, ou rien s'il ne se lit pas. */
    private fun copyToCache(context: Context, uri: Uri): File? {
        val file = runCatching { File.createTempFile("import", ".pdf", context.cacheDir) }.getOrNull() ?: return null
        val copied = runCatching {
            context.contentResolver.openInputStream(uri)?.use { input -> file.outputStream().use { input.copyTo(it) } } != null
        }.getOrDefault(false)
        if (!copied || file.length() == 0L) {
            file.delete()
            return null
        }
        return file
    }

    private fun embeddedText(context: Context, file: File): String = try {
        PDFBoxResourceLoader.init(context.applicationContext)
        // Un gros PDF passe par un fichier temporaire plutôt que par la mémoire, et seules les
        // deux cents premières pages sont lues : le serveur n'en lit pas plus de 60 000 signes.
        PDDocument.load(file, MemoryUsageSetting.setupMixed(24L * 1024 * 1024)).use { document ->
            normalize(PDFTextStripper().apply { sortByPosition = true; endPage = 200 }.getText(document))
        }
    } catch (error: InvalidPasswordException) {
        throw ImportException(R.string.ios_pdf_protected)
    } catch (error: Throwable) {
        // Un PDF que PDFBox ne sait pas lire peut encore se rendre et passer à l'OCR.
        ""
    }

    private fun render(renderer: PdfRenderer, index: Int, maxDimension: Int): Bitmap? = runCatching {
        val page = renderer.openPage(index)
        try {
            val longest = max(page.width, page.height).coerceAtLeast(1)
            val scale = minOf(maxDimension.toFloat() / longest, 3f)
            val bitmap = Bitmap.createBitmap((page.width * scale).roundToInt().coerceAtLeast(1), (page.height * scale).roundToInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
            Canvas(bitmap).drawColor(Color.WHITE)
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            bitmap
        } finally {
            page.close()
        }
    }.getOrNull()
}

/** **Des photos ou un scan** (`PhotoImportService`) : l'OCR sur le téléphone, et les pages en images. */
object PhotoImport {
    const val MAX_PAGES = 20

    suspend fun read(context: Context, uris: List<Uri>, name: String): ImportedDocument = withContext(Dispatchers.IO) {
        val pages = uris.take(MAX_PAGES)
        if (pages.isEmpty()) throw ImportException(R.string.ios_photo_empty)
        val texts = mutableListOf<String>()
        val images = mutableListOf<String>()
        for ((index, uri) in pages.withIndex()) {
            ensureActive()
            val bitmap = ImagePrep.decode(context, uri, ImportLimits.OCR_DIMENSION) ?: continue
            texts.add(OnDeviceOcr.read(bitmap))
            if (index < ImportLimits.IMAGE_PAGES) images.add(ImagePrep.dataUrl(bitmap))
            bitmap.recycle()
        }
        if (images.isEmpty()) throw ImportException(R.string.ios_photo_unreadable)
        val text = normalize(texts.filter { it.isNotBlank() }.joinToString("\n\n"))
        ImportedDocument(text = text, images = images, name = name, source = "photo")
    }
}

/** **Un document Word** (`DocxImportService`) : le texte de `word/document.xml`, paragraphe par paragraphe. */
object DocxImport {
    suspend fun read(context: Context, uri: Uri): ImportedDocument = withContext(Dispatchers.IO) {
        val name = displayName(context, uri) ?: "Word"
        val xml = try {
            context.contentResolver.openInputStream(uri)?.use { stream ->
                ZipInputStream(stream).use { zip ->
                    var found: String? = null
                    while (true) {
                        val entry = zip.nextEntry ?: break
                        if (entry.name == "word/document.xml") {
                            found = zip.readBytes().toString(Charsets.UTF_8)
                            break
                        }
                    }
                    found
                }
            }
        } catch (error: IOException) {
            throw ImportException(R.string.ios_docx_corrupt)
        } ?: throw ImportException(R.string.ios_docx_notDocx)
        val text = normalize(paragraphs(xml).joinToString("\n\n"))
        if (text.length < 20) throw ImportException(R.string.ios_docx_empty)
        ImportedDocument(text = text, images = emptyList(), name = name, source = "docx")
    }

    private val paragraph = Regex("<w:p[ >][\\s\\S]*?</w:p>")
    private val piece = Regex("<w:t(?: [^>]*)?>([\\s\\S]*?)</w:t>|<w:tab/>|<w:br/>")

    private fun paragraphs(xml: String): List<String> = paragraph.findAll(xml).map { match ->
        piece.findAll(match.value).joinToString("") { part ->
            when {
                part.value == "<w:tab/>" -> "\t"
                part.value == "<w:br/>" -> "\n"
                else -> unescape(part.groupValues[1])
            }
        }.trim()
    }.filter { it.isNotEmpty() }.toList()

    private fun unescape(value: String): String = value
        .replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'").replace("&amp;", "&")
}
