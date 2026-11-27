const $ = (id) => document.getElementById(id);

const fileInput = $("file"), drop = $("drop");
const preview = $("preview"), photo = $("photo"), hogImg = $("hogImg");
const enrollStatus = $("enrollStatus"), camStatus = $("camStatus");
const camBtn = $("camBtn"), thr = $("thr"), thrVal = $("thrVal");
const video = $("video"), overlay = $("overlay"), wrap = $("videoWrap"), banner = $("banner");

let enrolled = false;
let stream = null;
let running = false;
let history = []; // últimos resultados (suavização)

let wasMatch = false; // estado anterior, para apitar só na transição "sem match" -> "match"

function setStatus(el, msg, cls = "") { el.textContent = msg; el.className = "status " + cls; }

/* ---------------- Beep (Web Audio API) ---------------- */
let audioCtx = null;
function initAudio() { // precisa ser chamado num clique (política de autoplay dos navegadores)
  if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  if (audioCtx.state === "suspended") audioCtx.resume();
}

function beep() {
  if (!audioCtx) return;
  const t = audioCtx.currentTime;
  // dois apitos curtos: 880 Hz e 1320 Hz
  [[880, 0], [1320, 0.16]].forEach(([freq, delay]) => {
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = "sine";
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(0.0001, t + delay);
    gain.gain.exponentialRampToValueAtTime(0.4, t + delay + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + delay + 0.13);
    osc.connect(gain).connect(audioCtx.destination);
    osc.start(t + delay);
    osc.stop(t + delay + 0.15);
  });
}

/* ---------------- 1. Cadastro da foto ---------------- */
drop.addEventListener("dragover", (e) => { e.preventDefault(); drop.classList.add("over"); });
drop.addEventListener("dragleave", () => drop.classList.remove("over"));
drop.addEventListener("drop", (e) => {
  e.preventDefault(); drop.classList.remove("over");
  if (e.dataTransfer.files[0]) enroll(e.dataTransfer.files[0]);
});
fileInput.addEventListener("change", () => fileInput.files[0] && enroll(fileInput.files[0]));

async function enroll(file) {
  setStatus(enrollStatus, "Extraindo embedding HOG…");
  enrolled = false; camBtn.disabled = true;

  try {
    const res = await fetch("/api/enroll", { method: "POST", body: file,
                                             headers: { "Content-Type": file.type || "image/jpeg" } });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || "Erro ao cadastrar");

    await drawPhoto(file, data);
    hogImg.src = data.hog_png;
    preview.hidden = false;

    enrolled = true; camBtn.disabled = false;
    const extra = data.faces_found > 1 ? ` (${data.faces_found} rostos; usei o maior)` : "";
    setStatus(enrollStatus,
      `Embedding extraído: ${data.dims} dimensões, ${data.variants} variações${extra}.`, "ok");
    setStatus(camStatus, running ? "Comparando…" : "Pronto! Clique em “Abrir webcam”.");
  } catch (err) {
    preview.hidden = true;
    setStatus(enrollStatus, err.message, "err");
  }
}

function drawPhoto(file, info) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => {
      // o servidor pode ter reduzido a imagem: converte a caixa para a escala original
      const k = img.naturalWidth / info.image_w;
      const [x, y, w, h] = info.box.map((v) => v * k);
      photo.width = img.naturalWidth; photo.height = img.naturalHeight;
      const ctx = photo.getContext("2d");
      ctx.drawImage(img, 0, 0);
      ctx.lineWidth = Math.max(3, img.naturalWidth / 150);
      ctx.strokeStyle = "#22c55e";
      ctx.strokeRect(x, y, w, h);
      URL.revokeObjectURL(img.src);
      resolve();
    };
    img.src = URL.createObjectURL(file);
  });
}

/* ---------------- 2. Webcam ---------------- */
thr.addEventListener("input", () => (thrVal.textContent = (+thr.value).toFixed(2)));
camBtn.addEventListener("click", () => (stream ? stopCam() : startCam()));

async function startCam() {
  initAudio();
  wasMatch = false;
  try {
    stream = await navigator.mediaDevices.getUserMedia({ video: { width: 640, height: 480 }, audio: false });
  } catch (err) {
    setStatus(camStatus, "Não consegui acessar a webcam: " + err.message, "err");
    return;
  }
  video.srcObject = stream;
  await video.play();
  camBtn.textContent = "Fechar webcam"; camBtn.classList.add("stop");
  setStatus(camStatus, "Comparando…");
  running = true; history = [];
  loop();
}

function stopCam() {
  running = false;
  stream.getTracks().forEach((t) => t.stop());
  stream = null; video.srcObject = null;
  overlay.getContext("2d").clearRect(0, 0, overlay.width, overlay.height);
  camBtn.textContent = "Abrir webcam"; camBtn.classList.remove("stop");
  wrap.className = "video-wrap"; banner.textContent = "Aguardando…";
  setStatus(camStatus, "Webcam fechada.");
}

const grab = document.createElement("canvas"); // frame reduzido enviado ao servidor

async function loop() {
  while (running) {
    const t0 = performance.now();
    try { await tick(); } catch (e) { setStatus(camStatus, "Erro: " + e.message, "err"); }
    const wait = Math.max(0, 150 - (performance.now() - t0)); // ~6 fps no máximo
    await new Promise((r) => setTimeout(r, wait));
  }
}

async function tick() {
  if (!video.videoWidth) return;
  const W = 480, H = Math.round((video.videoHeight / video.videoWidth) * W);
  grab.width = W; grab.height = H;
  grab.getContext("2d").drawImage(video, 0, 0, W, H);
  const blob = await new Promise((r) => grab.toBlob(r, "image/jpeg", 0.75));

  const res = await fetch(`/api/match?threshold=${thr.value}`, { method: "POST", body: blob,
                                                                 headers: { "Content-Type": "image/jpeg" } });
  const data = await res.json();
  if (!running) return;
  render(data);
}

function render(data) {
  overlay.width = video.videoWidth; overlay.height = video.videoHeight;
  const ctx = overlay.getContext("2d");
  ctx.clearRect(0, 0, overlay.width, overlay.height);

  const faces = data.faces || [];
  const k = overlay.width / data.frame_w;
  let best = null;

  for (const f of faces) {
    const [x, y, w, h] = f.box.map((v) => v * k);
    const mx = overlay.width - (x + w); // vídeo está espelhado
    const color = f.match ? "#22c55e" : "#ef4444";
    ctx.lineWidth = 4; ctx.strokeStyle = color;
    ctx.strokeRect(mx, y, w, h);

    const label = `${f.match ? "MATCH" : "?"} ${f.score.toFixed(2)}`;
    ctx.font = "bold 20px system-ui, sans-serif";
    const tw = ctx.measureText(label).width + 12;
    ctx.fillStyle = color; ctx.fillRect(mx, Math.max(0, y - 28), tw, 28);
    ctx.fillStyle = "#fff"; ctx.fillText(label, mx + 6, Math.max(20, y - 7));
    if (!best || f.score > best.score) best = f;
  }

  // suavização: considera "match" se 2 dos últimos 3 frames deram match
  history.push(best ? (best.match ? 1 : 0) : -1);
  if (history.length > 3) history.shift();
  const hits = history.filter((v) => v === 1).length;
  const seen = history.filter((v) => v >= 0).length;

  const isMatch = !!best && (hits >= 2 || (history.length < 3 && hits >= 1));

  if (!best) {
    wrap.className = "video-wrap"; banner.textContent = "Nenhum rosto detectado";
  } else if (isMatch) {
    wrap.className = "video-wrap match"; banner.textContent = `✅ MATCH! (score ${best.score.toFixed(2)})`;
    if (!wasMatch) beep(); // apita ao entrar em match
  } else {
    wrap.className = "video-wrap nomatch"; banner.textContent = `❌ Sem match (score ${best.score.toFixed(2)})`;
  }
  wasMatch = isMatch;
}