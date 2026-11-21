import unittest

from matching import match_faces


class MatchVotingTest(unittest.TestCase):
    joao = [1, 0, 0, 0]
    lucas = [0, 1, 0, 0]
    jose = [0, 0, 1, 0]
    unknown = [0, 0, 0, 1]

    def match(self, *captures):
        return match_faces(
            {"joao": self.joao, "lucas": self.lucas, "jose": self.jose},
            captures,
            minimum_score=0.75,
            minimum_margin=0.08,
        )

    def test_three_different_candidates_are_unknown(self):
        self.assertEqual(
            self.match(self.joao, self.lucas, self.jose),
            ("UNKNOWN_FACE", None, None),
        )

    def test_one_recognized_candidate_wins_over_unknown_frames(self):
        self.assertEqual(
            self.match(self.joao, self.unknown, self.unknown),
            ("MATCH", "joao", 1.0),
        )

    def test_two_votes_win_and_score_uses_only_winning_frames(self):
        result, user_id, score = self.match(self.joao, self.lucas, [0.8, 0, 0, 0.6])
        self.assertEqual((result, user_id), ("MATCH", "joao"))
        self.assertAlmostEqual(score, 0.8)

    def test_two_candidates_with_equal_votes_are_unknown(self):
        self.assertEqual(
            self.match(self.joao, self.lucas, self.unknown),
            ("UNKNOWN_FACE", None, None),
        )

    def test_all_unknown_frames_produce_no_match(self):
        self.assertEqual(
            self.match(self.unknown, self.unknown, self.unknown),
            ("UNKNOWN_FACE", None, None),
        )
