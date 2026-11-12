const C = { body:'#3870FE', shade:'#2A5BE0', ink:'#14182B', pencil:'#F7B41F', eraser:'#E3596C', cheek:'#FF8FA8', wood:'#F6DDB6', spark:'#F7B41F' };
// Chaque expression = paramètres. Tout le dessin tient dans un viewBox 400x400, pieds posés à y=344.
function mika(o){
  o = Object.assign({ eyes:'open', px:0, py:0, mouth:'smile', leftArm:'rest', rightArm:'pencil', extra:'', tilt:0, body:C.body, shade:C.shade }, o);
  const eye = (cx) => {
    if(o.eyes==='happy') return `<path d="M${cx-22} 176 Q${cx} 146 ${cx+22} 176" fill="none" stroke="${C.ink}" stroke-width="9" stroke-linecap="round"/>`;
    if(o.eyes==='closed') return `<path d="M${cx-20} 172 Q${cx} 184 ${cx+20} 172" fill="none" stroke="${C.ink}" stroke-width="8" stroke-linecap="round"/>`;
    const ry = o.eyes==='wide' ? 38 : 34, rx = o.eyes==='wide' ? 30 : 28;
    const pr = o.eyes==='wide' ? 0.85 : 1;
    const dx = (cx<200? 5 : -5) + o.px, dy = 6 + o.py;
    return `<ellipse cx="${cx}" cy="166" rx="${rx}" ry="${ry}" fill="#fff"/>
            <ellipse cx="${cx+dx}" cy="${166+dy}" rx="${15*pr}" ry="${19*pr}" fill="${C.ink}"/>
            <circle cx="${cx+dx-6}" cy="${166+dy-9}" r="6" fill="#fff"/>`;
  };
  const wink = o.eyes==='wink';
  const eyes = wink
    ? eye(158).replace('','') && (()=>{ const s=o.eyes; o.eyes='open'; const l=eye(158); o.eyes='happy'; const r=eye(242); o.eyes=s; return l+r; })()
    : eye(158)+eye(242);
  const mouths = {
    smile:`<path d="M184 212 Q200 228 216 212" fill="none" stroke="${C.ink}" stroke-width="7" stroke-linecap="round"/>`,
    open:`<path d="M178 208 Q200 206 222 208 Q218 240 200 240 Q182 240 178 208 Z" fill="${C.ink}"/><path d="M188 229 Q200 221 212 229 Q208 240 200 240 Q192 240 188 229 Z" fill="#FF7A8F"/>`,
    o:`<ellipse cx="200" cy="220" rx="11" ry="14" fill="${C.ink}"/>`,
    flat:`<path d="M188 218 L212 218" fill="none" stroke="${C.ink}" stroke-width="7" stroke-linecap="round"/>`,
    sad:`<path d="M186 224 Q200 210 214 224" fill="none" stroke="${C.ink}" stroke-width="7" stroke-linecap="round"/>`,
    small:`<path d="M190 214 Q200 222 210 214" fill="none" stroke="${C.ink}" stroke-width="7" stroke-linecap="round"/>`
  };
  const left = {
    rest:`<path d="M110 232 Q66 250 60 298 Q58 318 76 316"/>`,
    wave:`<path d="M106 214 Q58 196 50 142 Q48 124 64 122"/>`,
    up:`<path d="M112 200 Q70 150 74 96"/>`,
    chin:`<path d="M112 240 Q110 290 168 262"/>`
  }[o.leftArm];
  const rightArmPath = { pencil:`M290 232 Q340 240 346 192`, up:`M288 200 Q330 150 326 96`, write:`M290 236 Q330 268 318 300`, rest:`M290 232 Q334 250 340 298 Q342 318 324 316`, tilt:`M290 232 Q340 240 346 192` }[o.rightArm];
  const pencil = o.rightArm==='tilt' ? `<g transform="rotate(-24 346 192)"><rect x="335" y="88" width="22" height="84" rx="5" fill="${C.pencil}"/><rect x="335" y="160" width="22" height="14" rx="5" fill="${C.eraser}"/><path d="M335 92 L346 64 L357 92 Z" fill="${C.wood}"/><path d="M341.5 76 L346 64 L350.5 76 Z" fill="${C.ink}"/></g><circle cx="346" cy="192" r="23" fill="${o.body}"/>` : o.rightArm==='pencil'
    ? `<g transform="rotate(14 346 150)"><rect x="335" y="88" width="22" height="84" rx="5" fill="${C.pencil}"/><rect x="335" y="160" width="22" height="14" rx="5" fill="${C.eraser}"/><path d="M335 92 L346 64 L357 92 Z" fill="${C.wood}"/><path d="M341.5 76 L346 64 L350.5 76 Z" fill="${C.ink}"/></g><circle cx="346" cy="192" r="23" fill="${o.body}"/>`
    : o.rightArm==='up' ? `<g transform="rotate(-12 326 60)"><rect x="315" y="10" width="22" height="84" rx="5" fill="${C.pencil}"/><rect x="315" y="82" width="22" height="14" rx="5" fill="${C.eraser}"/><path d="M315 14 L326 -14 L337 14 Z" fill="${C.wood}"/><path d="M321.5 -2 L326 -14 L330.5 -2 Z" fill="${C.ink}"/></g><circle cx="326" cy="96" r="23" fill="${o.body}"/>`
    : o.rightArm==='write' ? `<g transform="rotate(205 318 300)"><rect x="307" y="230" width="22" height="84" rx="5" fill="${C.pencil}"/><rect x="307" y="302" width="22" height="14" rx="5" fill="${C.eraser}"/><path d="M307 234 L318 206 L329 234 Z" fill="${C.wood}"/><path d="M313.5 218 L318 206 L322.5 218 Z" fill="${C.ink}"/></g><circle cx="318" cy="300" r="23" fill="${o.body}"/>` : '';
  const sparkAt = o.rightArm==='up' ? [372,30] : [320,44];
  const spark = ((o.rightArm==='pencil'&&!o.extra)||o.rightArm==='up') ? `<path transform="translate(${sparkAt[0]} ${sparkAt[1]})" fill="${C.spark}" d="M0 -20 Q4 -4 20 0 Q4 4 0 20 Q-4 4 -20 0 Q-4 -4 0 -20 Z"/>` : '';
  const sticker = o.sticker ? `<g fill="none" stroke="#fff" stroke-width="${46+2*o.sticker}" stroke-linecap="round" stroke-linejoin="round"><path d="M152 262 Q144 300 134 326"/><path d="M248 262 Q256 300 266 326"/>${left}<path d="M200 270 L200 332"/><path d="${rightArmPath}"/></g><path fill="#fff" stroke="#fff" stroke-width="${2*o.sticker}" d="M200 44 C282 44 326 104 326 174 C326 244 274 288 200 288 C126 288 74 244 74 174 C74 104 118 44 200 44 Z"/>` : '';
  return `<svg width="${o.size||200}" height="${o.size||200}" viewBox="${o.viewBox||'-10 -30 420 420'}">
  ${o.noShadow?'':`<ellipse cx="200" cy="350" rx="110" ry="12" fill="#14182B" opacity=".07"/>`}
  <g transform="rotate(${o.tilt} 200 300)">${sticker}
  <g fill="none" stroke="${o.shade}" stroke-width="46" stroke-linecap="round"><path d="M152 262 Q144 300 134 326"/><path d="M248 262 Q256 300 266 326"/></g>
  <g fill="none" stroke="${o.body}" stroke-width="46" stroke-linecap="round" stroke-linejoin="round">${left}<path d="M200 270 L200 332"/><path d="${rightArmPath}"/></g>
  <path fill="${o.body}" d="M200 44 C282 44 326 104 326 174 C326 244 274 288 200 288 C126 288 74 244 74 174 C74 104 118 44 200 44 Z"/>
  <ellipse cx="144" cy="94" rx="32" ry="15" fill="#fff" opacity=".26" transform="rotate(-28 144 94)"/>
  ${pencil}${spark}
  ${eyes}
  <ellipse cx="116" cy="212" rx="18" ry="11" fill="${C.cheek}" opacity=".8"/><ellipse cx="284" cy="212" rx="18" ry="11" fill="${C.cheek}" opacity=".8"/>
  ${mouths[o.mouth]}
  </g>${o.extra}</svg>`;
}
const dots = `<g fill="#8FA9FF"><circle cx="318" cy="20" r="9"/><circle cx="346" cy="8" r="11"/><circle cx="378" cy="-6" r="13"/></g>`;
const lines = `<g stroke="#F7B41F" stroke-width="7" stroke-linecap="round"><path d="M262 58 L250 40"/><path d="M286 44 L282 22"/><path d="M244 80 L226 70"/></g>`;
const zzz = `<g fill="#8FA9FF" font-family="Helvetica" font-weight="900"><text x="300" y="70" font-size="40">z</text><text x="335" y="36" font-size="28">z</text></g>`;
const confetti = `<g><rect x="40" y="40" width="14" height="14" rx="3" fill="#F7B41F" transform="rotate(20 47 47)"/><rect x="350" y="150" width="12" height="12" rx="3" fill="#E3596C" transform="rotate(-15 356 156)"/><circle cx="60" cy="150" r="7" fill="#35C28B"/><circle cx="200" cy="8" r="7" fill="#E3596C"/><rect x="120" y="0" width="12" height="12" rx="3" fill="#8FA9FF" transform="rotate(30 126 6)"/><rect x="280" y="-6" width="14" height="14" rx="3" fill="#35C28B" transform="rotate(12 287 1)"/></g>`;

window.mika = mika; window.MIKA = { confetti, zzz, dots, lines };
