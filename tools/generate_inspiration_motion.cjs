'use strict';

const fs = require('node:fs');
const path = require('node:path');

let chromium;
try {
  ({chromium} = require('playwright'));
} catch (_) {
  ({chromium} = require(path.join(__dirname, '..', 'web', 'node_modules', 'playwright')));
}

const output = path.join(__dirname, '..', 'web', 'public', 'assets', 'examples');
const scenes = [
  'night-drive', 'forest-chase', 'rooftop-music',
  'fantasy-portal', 'product-orbit', 'clay-character',
];

async function render(scene) {
  const browser = await chromium.launch({headless: true});
  try {
    const page = await browser.newPage({viewport: {width: 640, height: 360}, deviceScaleFactor: 1});
    await page.setContent('<canvas id="motion" width="640" height="360"></canvas>');
    return await page.evaluate(async (sceneId) => {
      const canvas = document.querySelector('#motion');
      const ctx = canvas.getContext('2d', {alpha: false});
      const width = canvas.width;
      const height = canvas.height;
      const duration = 4;
      const stream = canvas.captureStream(24);
      const mimeType = ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm']
        .find((type) => MediaRecorder.isTypeSupported(type));
      if (!mimeType) throw new Error('This browser cannot render the local WebM examples.');
      const recorder = new MediaRecorder(stream, {mimeType, videoBitsPerSecond: 520000});
      const chunks = [];
      recorder.ondataavailable = (event) => { if (event.data.size) chunks.push(event.data); };
      const stopped = new Promise((resolve, reject) => {
        recorder.onerror = () => reject(new Error('The motion example could not be recorded.'));
        recorder.onstop = async () => {
          for (const track of stream.getTracks()) track.stop();
          const bytes = new Uint8Array(await new Blob(chunks, {type: mimeType}).arrayBuffer());
          let binary = '';
          for (let offset = 0; offset < bytes.length; offset += 0x8000) {
            binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
          }
          resolve({mimeType, base64: btoa(binary)});
        };
      });
      const polygon = (points, fill) => {
        ctx.fillStyle = fill;
        ctx.beginPath();
        points.forEach(([x, y], index) => index ? ctx.lineTo(x, y) : ctx.moveTo(x, y));
        ctx.closePath();
        ctx.fill();
      };
      const ellipse = (x, y, rx, ry, fill) => {
        ctx.fillStyle = fill;
        ctx.beginPath();
        ctx.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2);
        ctx.fill();
      };
      const gradient = (top, bottom) => {
        const fill = ctx.createLinearGradient(0, 0, 0, height);
        fill.addColorStop(0, top);
        fill.addColorStop(1, bottom);
        ctx.fillStyle = fill;
        ctx.fillRect(0, 0, width, height);
      };
      const overlay = () => {
        const fill = ctx.createLinearGradient(0, height - 54, 0, height);
        fill.addColorStop(0, 'rgba(5,8,18,0)');
        fill.addColorStop(1, 'rgba(5,8,18,.82)');
        ctx.fillStyle = fill;
        ctx.fillRect(0, height - 54, width, 54);
        ctx.fillStyle = '#eff4ff';
        ctx.font = '600 11px system-ui, sans-serif';
        ctx.textAlign = 'left';
        ctx.fillText('HOTICE MOTION STUDY  ·  CONCEPT ONLY  ·  NOT AI OUTPUT', 18, height - 17);
      };
      const draw = (t) => {
        if (sceneId === 'night-drive') {
          gradient('#100d2d', '#070c18');
          ellipse(470, 112, 66, 66, '#eb63c42e');
          ellipse(470, 112, 49, 49, '#fd88c8');
          ctx.fillStyle = '#120f2c';
          ctx.fillRect(0, 180, width, 180);
          for (let i = 0; i < 18; i++) {
            const x = i * 41 + Math.sin(i * 2.3) * 9;
            const h = 18 + (i * 23 % 58);
            ctx.fillStyle = i % 2 ? '#161d40' : '#20224a';
            ctx.fillRect(x, 180 - h, 25, h);
            ctx.fillStyle = i % 2 ? '#52e2f9' : '#ff6acf';
            for (let y = 188 - h; y < 175; y += 12) ctx.fillRect(x + 6, y, 3, 4);
          }
          polygon([[266, 184], [374, 184], [640, 360], [0, 360]], '#151a32');
          polygon([[311, 184], [329, 184], [351, 360], [289, 360]], '#272840');
          for (let i = 0; i < 9; i++) {
            const p = ((i / 9 + t * 0.42) % 1);
            const y = 186 + p * p * 210;
            const x = 320 + (p * 190) * (i % 2 ? 1 : -1);
            ctx.fillStyle = i % 2 ? '#ff56ca' : '#4deaff';
            ctx.fillRect(x - 2, y, 4 + p * 7, 4 + p * 13);
          }
          polygon([[244, 275], [276, 250], [358, 250], [395, 275], [376, 299], [259, 299]], '#171a2b');
          polygon([[278, 255], [294, 238], [342, 238], [365, 255]], '#56cfe555');
          ellipse(267, 288, 10, 5, '#ff64d8'); ellipse(372, 288, 10, 5, '#54eaff');
          for (let i = 0; i < 42; i++) {
            const x = (i * 71 + t * (80 + i % 4 * 35)) % width;
            const y = (i * 47 + t * (150 + i % 5 * 18)) % height;
            ctx.strokeStyle = '#a9d8ff63'; ctx.lineWidth = 1;
            ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x - 4, y + 13); ctx.stroke();
          }
        } else if (sceneId === 'forest-chase') {
          gradient('#b9d8d0', '#284c4d');
          ellipse(475, 94, 58, 58, '#f7dba6b8');
          for (let layer = 0; layer < 3; layer++) {
            const base = 160 + layer * 38;
            ctx.fillStyle = ['#587b69', '#365d51', '#23463f'][layer];
            for (let i = 0; i < 12; i++) {
              const x = ((i * 82 - t * (10 + layer * 20) + width * 2) % (width + 120)) - 60;
              const h = 85 + (i * 31 % 100) + layer * 15;
              polygon([[x, base], [x + 39, base - h], [x + 78, base]], ctx.fillStyle);
            }
          }
          polygon([[275, 195], [365, 195], [560, 360], [85, 360]], '#9c906c');
          polygon([[300, 196], [340, 196], [408, 360], [225, 360]], '#c8b58a');
          for (let i = 0; i < 17; i++) {
            const x = (i * 53 + t * (36 + i % 4 * 12)) % width;
            const y = (i * 39 + t * 47) % 215;
            ellipse(x, y, 3, 8, '#f2edcf99');
          }
          const run = Math.sin(t * Math.PI * 2) * 8;
          ellipse(320 + run, 257, 15, 16, '#171d22');
          ctx.strokeStyle = '#171d22'; ctx.lineWidth = 9; ctx.lineCap = 'round';
          ctx.beginPath(); ctx.moveTo(320 + run, 272); ctx.lineTo(320 + run, 311);
          ctx.moveTo(320 + run, 283); ctx.lineTo(300 + run, 300);
          ctx.moveTo(320 + run, 283); ctx.lineTo(341 + run, 275);
          ctx.moveTo(320 + run, 310); ctx.lineTo(302 + run, 336);
          ctx.moveTo(320 + run, 310); ctx.lineTo(342 + run, 331); ctx.stroke();
        } else if (sceneId === 'rooftop-music') {
          gradient('#ffbb9d', '#512d58');
          ellipse(485, 104, 72, 72, '#ffd885');
          ellipse(485, 104, 62, 62, '#ff9f7c');
          for (let i = 0; i < 13; i++) {
            const x = i * 54 - 4;
            const h = 66 + (i * 37 % 93);
            ctx.fillStyle = i % 2 ? '#30305a' : '#39305e';
            ctx.fillRect(x, 250 - h, 46, h + 110);
            ctx.fillStyle = '#ffdba85c';
            for (let y = 174 - h; y < 245; y += 17) ctx.fillRect(x + 8, y, 4, 6);
          }
          ctx.strokeStyle = '#ffd8cf72'; ctx.lineWidth = 2;
          for (let i = 0; i < 4; i++) {
            ctx.beginPath(); ctx.ellipse(320, 249, 70 + i * 34 + Math.sin(t * 3 + i) * 8,
              16 + i * 8, 0, 0, Math.PI * 2); ctx.stroke();
          }
          ellipse(320, 204, 16, 17, '#19192d');
          ctx.strokeStyle = '#19192d'; ctx.lineWidth = 12; ctx.lineCap = 'round';
          ctx.beginPath(); ctx.moveTo(320, 221); ctx.lineTo(320, 282);
          ctx.moveTo(320, 239); ctx.lineTo(286, 221 + Math.sin(t * 3) * 12);
          ctx.moveTo(320, 239); ctx.lineTo(353, 217 - Math.sin(t * 3) * 12);
          ctx.moveTo(320, 281); ctx.lineTo(300, 324);
          ctx.moveTo(320, 281); ctx.lineTo(341, 324); ctx.stroke();
          ctx.fillStyle = '#222039'; ctx.fillRect(0, 324, width, 36);
        } else if (sceneId === 'fantasy-portal') {
          gradient('#101532', '#321c4f');
          for (let i = 0; i < 3; i++) {
            const ring = ctx.createLinearGradient(130, 0, 510, 360);
            ring.addColorStop(0, '#76f1ed'); ring.addColorStop(.48, '#9c6cff'); ring.addColorStop(1, '#ff78d1');
            ctx.strokeStyle = ring; ctx.lineWidth = 12 - i * 2;
            ctx.beginPath();
            ctx.ellipse(320, 184, 99 + i * 16, 140 + i * 8, t * (i % 2 ? -.12 : .12), 0, Math.PI * 2);
            ctx.stroke();
          }
          ellipse(320, 186, 79, 116, '#24365e');
          const inside = ctx.createRadialGradient(320, 180, 6, 320, 180, 112);
          inside.addColorStop(0, '#f7abff'); inside.addColorStop(.45, '#7c67db'); inside.addColorStop(1, '#24365e');
          ellipse(320, 186, 73, 108, inside);
          for (let i = 0; i < 34; i++) {
            const a = i * 2.399 + t * .7;
            const r = 122 + (i * 17 % 88);
            ellipse(320 + Math.cos(a) * r, 182 + Math.sin(a) * r * .8,
              2 + i % 3, 2 + i % 3, i % 2 ? '#d8d1ff' : '#7df6ef');
          }
          polygon([[0, 300], [188, 267], [216, 360], [0, 360]], '#1c2340');
          polygon([[470, 264], [640, 292], [640, 360], [438, 360]], '#1c2340');
        } else if (sceneId === 'product-orbit') {
          gradient('#0b1728', '#132f47');
          const halo = ctx.createRadialGradient(320, 155, 18, 320, 155, 255);
          halo.addColorStop(0, '#1e5570'); halo.addColorStop(1, '#0b1728');
          ctx.fillStyle = halo; ctx.fillRect(0, 0, width, height);
          ctx.strokeStyle = '#73e7f58c'; ctx.lineWidth = 2;
          for (let i = 0; i < 3; i++) {
            ctx.beginPath(); ctx.ellipse(320, 237, 157 + i * 18, 31 + i * 7,
              -.1 + t * .1, 0, Math.PI * 2); ctx.stroke();
          }
          const x = 320 + Math.sin(t * Math.PI / 2) * 74;
          ctx.save(); ctx.translate(x, 181 + Math.sin(t * Math.PI) * 9); ctx.rotate(Math.sin(t * Math.PI / 2) * .11);
          const body = ctx.createLinearGradient(-53, -58, 56, 56);
          body.addColorStop(0, '#e8f5ff'); body.addColorStop(.35, '#90bad5'); body.addColorStop(1, '#3c6789');
          ctx.fillStyle = body; ctx.beginPath(); ctx.roundRect(-49, -62, 98, 124, 22); ctx.fill();
          ctx.fillStyle = '#16314c'; ctx.beginPath(); ctx.roundRect(-39, -51, 78, 101, 15); ctx.fill();
          ellipse(0, -3, 25, 25, '#79eaff'); ellipse(0, -3, 16, 16, '#1c4760');
          ctx.restore();
          polygon([[130, 275], [510, 275], [556, 318], [83, 318]], '#2c4658');
          polygon([[83, 318], [556, 318], [520, 344], [116, 344]], '#172a3a');
        } else {
          gradient('#b3f0e4', '#6ca7b3');
          ellipse(506, 93, 67, 67, '#fff0b1');
          polygon([[0, 256], [128, 217], [264, 254], [396, 209], [640, 252], [640, 360], [0, 360]], '#6db29a');
          polygon([[0, 292], [166, 257], [315, 294], [487, 249], [640, 286], [640, 360], [0, 360]], '#4a907e');
          const bounce = Math.abs(Math.sin(t * Math.PI * 2)) * 12;
          ctx.fillStyle = '#e58b72'; ctx.beginPath(); ctx.ellipse(320, 248 - bounce, 48, 57, 0, 0, Math.PI * 2); ctx.fill();
          ellipse(320, 189 - bounce, 43, 39, '#f0a184');
          ellipse(304, 186 - bounce, 5, 7, '#342d48'); ellipse(336, 186 - bounce, 5, 7, '#342d48');
          ctx.strokeStyle = '#75495a'; ctx.lineWidth = 3; ctx.beginPath();
          ctx.arc(320, 197 - bounce, 11, .15, Math.PI - .15); ctx.stroke();
          ellipse(295, 202 - bounce, 8, 5, '#f9b4a0'); ellipse(345, 202 - bounce, 8, 5, '#f9b4a0');
          ctx.fillStyle = '#f4d2a1'; ctx.beginPath(); ctx.roundRect(282, 296 - bounce, 30, 43, 13); ctx.fill();
          ctx.beginPath(); ctx.roundRect(329, 296 - bounce, 30, 43, 13); ctx.fill();
          for (let i = 0; i < 24; i++) {
            const x = (i * 97 + t * (20 + i % 4 * 12)) % width;
            const y = 45 + (i * 61 % 245);
            ellipse(x, y, 2 + i % 3, 2 + i % 3, '#fff4ca99');
          }
        }
        overlay();
      };
      recorder.start(160);
      const start = performance.now();
      const frame = (now) => {
        draw(Math.min(duration, Math.max(0, (now - start) / 1000)));
        if ((now - start) / 1000 < duration) requestAnimationFrame(frame);
        else setTimeout(() => recorder.stop(), 150);
      };
      requestAnimationFrame(frame);
      return await stopped;
    }, scene);
  } finally {
    await browser.close();
  }
}

async function main() {
  fs.mkdirSync(output, {recursive: true});
  for (const scene of scenes) {
    const rendered = await render(scene);
    const destination = path.join(output, scene + '.webm');
    fs.writeFileSync(destination, Buffer.from(rendered.base64, 'base64'));
    console.log(scene + ': ' + Math.round(fs.statSync(destination).size / 1024) + ' KiB (' + rendered.mimeType + ')');
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
