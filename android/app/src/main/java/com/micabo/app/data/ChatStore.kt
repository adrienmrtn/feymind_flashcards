package com.micabo.app.data

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import java.io.File
import java.util.UUID

/** **Une conversation avec Mika, hors leçon** (lot 12 de l'iPhone, `ChatScreen`). */
@Serializable
data class Conversation(
    val id: String = UUID.randomUUID().toString(),
    val title: String = "",
    val updatedAt: Long = System.currentTimeMillis(),
    val messages: List<ChatMessage> = emptyList(),
    /** Le texte lu sur les photos jointes (l'OCR du téléphone) : il part comme document joint. */
    val attachment: String = "",
    /** Combien de photos ont été jointes. */
    val photos: Int = 0,
)

/**
 * **Les conversations gardées** (« Chat Mika : conversations gardées, photos lues sur
 * l'appareil, historique ») : un fichier sur le téléphone, la plus récente d'abord. Rien de ce
 * que l'élève écrit ne part dans les statistiques.
 */
class ChatStore(context: Context) {
    private val file = File(context.filesDir, "chats.json")
    private val serializer = ListSerializer(Conversation.serializer())
    private val _all = MutableStateFlow(read())
    val all: StateFlow<List<Conversation>> = _all.asStateFlow()

    private fun read(): List<Conversation> = runCatching {
        if (!file.exists()) emptyList() else MicaboJson.decodeFromString(serializer, file.readText())
    }.getOrDefault(emptyList())

    private fun write(list: List<Conversation>) {
        val sorted = list.sortedByDescending { it.updatedAt }.take(MAX)
        _all.value = sorted
        runCatching { file.writeText(MicaboJson.encodeToString(serializer, sorted)) }
    }

    fun get(id: String?): Conversation? = id?.let { wanted -> _all.value.firstOrNull { it.id == wanted } }

    fun save(conversation: Conversation) {
        write(_all.value.filter { it.id != conversation.id } + conversation.copy(updatedAt = System.currentTimeMillis()))
    }

    fun delete(id: String) = write(_all.value.filter { it.id != id })

    fun clear() = write(emptyList())

    companion object {
        const val MAX = 100
        const val MAX_PHOTOS = 6
    }
}
