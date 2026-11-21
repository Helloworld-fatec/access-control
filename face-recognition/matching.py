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
    votes = {}
    ambiguous = False

    for row in similarities:
        winner = int(np.argmax(row))
        score = float(row[winner])
        if score < minimum_score:
            continue

        other_scores = np.delete(row, winner)
        if other_scores.size and score - float(other_scores.max()) < minimum_margin:
            ambiguous = True
            continue

        votes.setdefault(winner, []).append(score)

    if not votes:
        return ("AMBIGUOUS_FACE" if ambiguous else "UNKNOWN_FACE"), None, None

    most_votes = max(map(len, votes.values()))
    leaders = [candidate for candidate, scores in votes.items() if len(scores) == most_votes]
    if len(leaders) != 1:
        return "UNKNOWN_FACE", None, None

    winner = leaders[0]
    return "MATCH", ids[winner], min(votes[winner])
