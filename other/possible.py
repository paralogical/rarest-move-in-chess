# possible.py -- using a chess library, place 3 of every piece in every possible square,
# to find the number of possible unique moves. We use 3 of each kind of piece to get the possibility of
# (singly or doubly) diambiguated moves. 4 pieces wouldn't add any more moves, but 2 would miss some.
# Results are written to possibilities.txt file in the cwd.

# This is written in python to get access to an easy-to-use chess engine that lists legal moves for a position.
# Note that this library requires kings on the board to compute legal moves (pretty sensibly),
# so we must place kings. However, this affects counting legal moves. So, as a hacky workaround,
# we run the simulations with 3 semi-random placements of kings on the board.

import chess
import math
import re

from typing import Set


def progress(curr, total, width=60):
    pct = (curr) / (total)
    progress = math.floor(pct * width)
    print('[' + ('◼︎' * progress) +
          ('-' * (width-progress)) + '] (%.1f%%)' % (100.0 * pct))


with open('./possibilities.txt', 'w') as file:
    numExtra = 2
    pieces = ['R', 'B', 'N', 'Q']
    kingposes = [[61, 63], [17, 33], [4, 31]]  # king position permutations
    outer = 0
    for piece in pieces:
        moves: Set[str] = set()
        for kingpos in kingposes:
            iters = 0
            for i in range(64):  # place the first piece
                # j&k are 2nd and 3rd pieces (can only come after i, otherwise we're repeating positions)
                for j in range(i + 1, 64):
                    for k in range(j + 1, 64):
                        iters += 1
                        # create a board with just the pieces and kings
                        board = chess.Board('8/8/8/8/8/8/8/8')
                        board.set_piece_at(i, chess.Piece.from_symbol(piece))
                        board.set_piece_at(j, chess.Piece.from_symbol(piece))
                        board.set_piece_at(k, chess.Piece.from_symbol(piece))
                        board.set_piece_at(
                            kingpos[0], chess.Piece.from_symbol('k'))
                        board.set_piece_at(
                            kingpos[1], chess.Piece.from_symbol('K'))
                        for move in board.legal_moves:
                            # standard notation is what we want
                            san = board.san(move)
                            if san[0] == 'k' or san[0] == 'K':
                                continue  # ignore king moves
                            end = san[len(san)-1]
                            if end == '+' or end == '#':
                                # ignore checks and mates. Since we place kings only at a few positions (and don't iterate all of them),
                                # we don't expect we'd get full coverage of all checks & mates. Let's just analytically determine when checks&mates
                                # are possible and deduplicate them here.
                                san = san[:-1]
                            if 'x' in san:
                                # similarly, ignore captures. These shouldn't be possible but it is possible for a position to already be check thus queen-takes-king are sometimes generated.
                                san = san.replace('x', '')
                            moves.add(san)
                        # print progress occasionally
                        if iters % 500 == 0:
                            print(chr(27) + "[2J")
                            print(board)
                            print('moves seen: %d' % len(moves))
                            progress(outer + ((64 * i + j) / (64*64)),
                                     len(pieces) * len(kingposes))
                            progress(64 * i + j, 64*64)
            outer += 1

        s = '-------- %s --------\n' % piece
        moveslist = list(moves)
        s += "%s\n\n" % (str(moveslist))
        s += "%d iters\n\n" % iters
        s += "%d total moves\n" % len(moves)
        # regexes to tell if a move is disambiguated
        regexes = [
            ('normal', re.compile(r'^[KQNRB][a-h][1-8]$')),
            ('file disambiguated', re.compile(r'^[KQNRB][a-h][a-h][1-8]$')),
            ('rank disambiguated', re.compile(r'^[KQNRB][1-8][a-h][1-8]$')),
            ('rank&file disambiguated', re.compile(
                r'^[KQNRB][a-h][1-8][a-h][1-8]$')),
        ]
        for (name, r) in regexes:
            moves = [move for move in moveslist if r.match(move)]
            s += '%d %s moves\n' % (len(moves), name)
        print(s)
        s += '\n\n'
        file.write(s)
        file.flush()
