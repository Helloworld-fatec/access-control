import numpy as np


def unit_rows(vectors):
    matrix = np.asarray(vectors, dtype=np.float64)
    if not np.all(np.isfinite(matrix)) or np.any(matrix < 0) or np.any(matrix > 1):
        raise ValueError("Invalid HOG descriptor")
    norms = np.linalg.norm(matrix, axis=1, keepdims=True)
    if np.any(norms == 0):
        raise ValueError("Empty HOG descriptor")
    return matrix / norms


def match_faces(candidates, captures, minimum_score, minimum_margin):
    ids = list(candidates)
    templates = unit_rows(list(candidates.values()))
    similarities = np.clip(unit_rows(captures) @ templates.T, 0.0, 1.0)
    winners = set()
    scores = []
    unknown = False

    for row in similarities:
        winner = int(np.argmax(row))
        score = float(row[winner])
        if score < minimum_score:
            unknown = True
            continue

        other_scores = np.delete(row, winner)
        if other_scores.size and score - float(other_scores.max()) < minimum_margin:
            return "AMBIGUOUS_FACE", None, None

        winners.add(winner)
        scores.append(score)

    if len(winners) > 1:
        return "AMBIGUOUS_FACE", None, None
    if unknown:
        return "UNKNOWN_FACE", None, None
    return "MATCH", ids[winners.pop()], min(scores)
