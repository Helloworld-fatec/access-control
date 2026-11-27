import { useCallback, useEffect, useRef, useState } from "react";
import type { PokemonDraw, Visit } from "../../shared/types";
import { errorMessage, Modal, QueryState } from "../../shared/ui";
import PokemonImage, { pokemonImageUrl } from "../pokemon/PokemonImage";

const clipUrl = `${import.meta.env.BASE_URL}pokebola-clipe.mp4`;
const countdownSeconds = 5;
const lightTimeoutMs = 750;
const clipTimeoutMs = 10_000;
type Phase = "countdown" | "video" | "light" | "revealed";

interface Props {
  visit: Visit;
  draw: PokemonDraw | undefined;
  drawing: boolean;
  drawError: unknown;
  claiming: boolean;
  claimError: unknown;
  onRetry: () => void;
  onClaim: () => void;
  onClose: () => void;
}

export default function PokemonCheckoutDialog(props: Props) {
  const { visit, draw, drawing, drawError, claiming, onRetry, onClose } = props;
  return (
    <Modal title="Sortear Pokémon" onClose={onClose} preventClose={claiming} wide>
      <p>{visit.user?.name}</p>
      <QueryState isLoading={drawing} error={drawError} empty={!draw} emptyText="Aguardando sorteio…" onRetry={onRetry}>
        {draw && <PokemonReveal key={draw.visitId} {...props} draw={draw} />}
      </QueryState>
      {!draw && <div className="actions"><button className="btn" onClick={onClose}>Voltar</button></div>}
    </Modal>
  );
}

function PokemonReveal({
  draw, claiming, claimError, onClaim, onClose,
}: Pick<Props, "claiming" | "claimError" | "onClaim" | "onClose"> & { draw: PokemonDraw }) {
  const [phase, setPhase] = useState<Phase>("countdown");
  const [remaining, setRemaining] = useState(countdownSeconds);
  const [reduceMotion] = useState(() => window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches ?? false);
  const video = useRef<HTMLVideoElement>(null);
  const videoFailed = useRef(false);

  useEffect(() => {
    const path = draw.pokemon.imagem_url;
    if (path) {
      const image = new Image();
      image.src = pokemonImageUrl(path);
    }
  }, [draw.pokemon.imagem_url]);

  useEffect(() => {
    const deadline = Date.now() + countdownSeconds * 1000;
    let timer: number;
    const tick = () => {
      const milliseconds = deadline - Date.now();
      if (milliseconds <= 0) {
        setPhase(reduceMotion ? "revealed" : videoFailed.current ? "light" : "video");
        return;
      }
      const seconds = Math.ceil(milliseconds / 1000);
      setRemaining(seconds);
      timer = window.setTimeout(tick, milliseconds - (seconds - 1) * 1000);
    };
    timer = window.setTimeout(tick, 1000);
    return () => window.clearTimeout(timer);
  }, [reduceMotion]);

  const finishVideo = useCallback(() => {
    setPhase((current) => current === "video" ? "light" : current);
  }, []);

  const reveal = useCallback(() => {
    setPhase((current) => current === "light" ? "revealed" : current);
  }, []);

  useEffect(() => {
    if (phase === "video") {
      const clip = video.current;
      const timer = window.setTimeout(finishVideo, clipTimeoutMs);
      void clip?.play()?.catch(finishVideo);
      return () => {
        window.clearTimeout(timer);
        if (clip && !clip.paused) clip.pause();
      };
    }
    if (phase === "light") {
      const timer = window.setTimeout(reveal, lightTimeoutMs);
      return () => window.clearTimeout(timer);
    }
  }, [phase, finishVideo, reveal]);

  return (
    <>
      {phase === "countdown" && (
        <div className="pokemon-countdown">
          <p role="status">Preparando a revelação</p>
          <strong className="nums" aria-hidden="true">{remaining}</strong>
        </div>
      )}
      {!reduceMotion && phase !== "revealed" && (
        <video
          ref={video}
          className="pokemon-clip"
          src={clipUrl}
          hidden={phase === "countdown"}
          muted
          playsInline
          preload="auto"
          aria-hidden="true"
          onEnded={finishVideo}
          onError={() => {
            videoFailed.current = true;
            finishVideo();
          }}
        />
      )}
      {phase === "light" && <div className="pokemon-light" aria-hidden="true" onAnimationEnd={reveal} />}
      {phase === "revealed" && (
        <div className="pokemon-reveal">
          <PokemonImage pokemon={draw.pokemon} />
          <h3 role="status">{draw.pokemon.nome} <span className="muted">#{draw.pokemon.id}</span></h3>
        </div>
      )}
      {claimError ? <p className="form-error" role="alert">{errorMessage(claimError)}</p> : null}
      <div className="actions">
        <button className="btn" onClick={onClose} disabled={claiming}>Voltar</button>
        {phase === "revealed" && (
          <button className="btn btn-primary" onClick={onClaim} disabled={claiming}>
            {claiming ? "Registrando…" : "Pegar Pokémon"}
          </button>
        )}
      </div>
    </>
  );
}
