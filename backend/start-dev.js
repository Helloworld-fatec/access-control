import { execSync, spawn } from 'node:child_process';
import net from 'node:net';
import fs from 'node:fs';
import path from 'node:path';

function checkPort(port) {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    socket.setTimeout(800);
    socket.once('connect', () => {
      socket.destroy();
      resolve(true);
    });
    socket.once('timeout', () => {
      socket.destroy();
      resolve(false);
    });
    socket.once('error', () => {
      resolve(false);
    });
    socket.connect(port, '127.0.0.1');
  });
}

async function start() {
  const isDbRunning = await checkPort(5433);
  if (!isDbRunning) {
    console.log('[Dev] Iniciando banco de dados PostgreSQL na porta 5433...');
    const pidFile = path.resolve('.pgdata-test/postmaster.pid');
    if (fs.existsSync(pidFile)) {
      try {
        fs.unlinkSync(pidFile);
      } catch (_) {}
    }
    const pgCtl = 'C:\\Program Files\\PostgreSQL\\17\\bin\\pg_ctl.exe';
    try {
      execSync(`"${pgCtl}" -D .pgdata-test -o "-p 5433" start`, { stdio: 'inherit' });
    } catch (e) {
      console.warn('[Dev] Aviso ao iniciar banco:', e.message);
    }
  } else {
    console.log('[Dev] Banco de dados já está ativo na porta 5433.');
  }

  let faceProcess = null;
  const isFaceRunning = await checkPort(8000);
  if (!isFaceRunning) {
    const faceServiceScript = path.resolve('../face-service/server.py');
    if (fs.existsSync(faceServiceScript)) {
      console.log('[Dev] Iniciando serviço de Visão Facial Python HOG na porta 8000...');
      faceProcess = spawn('python', [faceServiceScript, '8000'], {
        stdio: 'inherit',
        shell: true,
      });
    }
  } else {
    console.log('[Dev] Serviço Facial Python HOG já está ativo na porta 8000.');
  }

  const tsx = spawn('npx', ['tsx', 'watch', 'src/server.ts'], {
    stdio: 'inherit',
    shell: true,
  });

  const cleanup = () => {
    if (faceProcess) {
      try {
        faceProcess.kill();
      } catch (_) {}
    }
    tsx.kill('SIGINT');
    process.exit(0);
  };

  process.on('SIGINT', cleanup);
  process.on('SIGTERM', cleanup);
}

start();
