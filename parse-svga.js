// 解析 svga 文件头：v1(zlib+protobuf) → MovieParams(宽/高/帧率/帧数)
// 用法：node parse-svga.js [文件路径 ...]
const z = require('zlib');
const fs = require('fs');

const files = process.argv.slice(2).length
  ? process.argv.slice(2)
  : ['F:/RN/SR/example/assets/svga/angel.svga', 'F:/RN/SR/example/assets/svga/rose.svga'];

function rv(buf, i) { // read varint
  let r = 0, s = 0;
  for (;;) {
    const x = buf[i++]; r += (x & 0x7f) * Math.pow(2, s);
    if (!(x & 0x80)) return [r, i];
    s += 7;
  }
}

for (const f of files) {
  const raw0 = fs.readFileSync(f);
  let b;
  const v2 = raw0.length > 3 && raw0[0] === 0x50 && raw0[1] === 0x4b; // PK zip
  if (v2) {
    console.log(`${f}: v2(zip) 容器，帧数需解 movie.spec，此处略`);
    continue;
  }
  b = z.inflateSync(raw0); // v1 zlib 流
  let i = 0; const out = {};
  while (i < b.length) {
    const [t, j] = rv(b, i); const fl = t >> 3, w = t & 7; i = j;
    if (w === 0) { const [v, k] = rv(b, i); i = k; out['field' + fl] = v; }
    else if (w === 5) i += 4; else if (w === 1) i += 8;
    else if (w === 2) {
      const [l, k] = rv(b, i); i = k; const sub = b.subarray(i, i + l); i += l;
      if (fl === 2) { // MovieParams
        let p = 0;
        const names = { 1: 'viewWidth', 2: 'viewHeight', 3: 'frameRate', 4: 'frameCount' };
        while (p < sub.length) {
          const [t2, q] = rv(sub, p); const f2 = t2 >> 3, w2 = t2 & 7; p = q;
          if (w2 === 0) { const [v2_, r2] = rv(sub, p); p = r2; out[names[f2] || ('param' + f2)] = v2_; }
          else if (w2 === 5) p += 4; else if (w2 === 1) p += 8;
          else if (w2 === 2) { const [l2, r2] = rv(sub, p); p = r2 + l2; }
        }
      }
    }
  }
  console.log(`${f}:\n  ${JSON.stringify(out)}`);
}
