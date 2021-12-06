// This script generates all possible moves in chess, focusing on categories of moves.
// Some moves are surprisingly not possible,
// such as certain double disambiguations that cannot be check or mate,
// or certain rank/double disambiguations that would be more properly written with a simpler disambiguation.

let currentSection = "";
let currentSubsection = "";

const sectionMoves: Record<string, Record<string, Array<string>>> = {};
const sectionExcludedMoves: Record<string, Record<string, Array<string>>> = {};

function section(name: string) {
  currentSection = name;
  sectionMoves[name] = {};
  sectionExcludedMoves[name] = {};
  subsection("normal");
}
function subsection(name: string) {
  currentSubsection = name;
  sectionMoves[currentSection][name] = [];
  sectionExcludedMoves[currentSection][name] = [];
}

function emit(move: string, checkAndMate: boolean = true) {
  sectionMoves[currentSection][currentSubsection].push(move);
  if (checkAndMate) {
    sectionMoves[currentSection][currentSubsection].push(move + "+");
    sectionMoves[currentSection][currentSubsection].push(move + "#");
  } else {
    sectionExcludedMoves[currentSection][currentSubsection].push(move + "+");
    sectionExcludedMoves[currentSection][currentSubsection].push(move + "#");
  }
}

function exclude(move: string, checkAndMate: boolean = true) {
  sectionExcludedMoves[currentSection][currentSubsection].push(move);
  if (checkAndMate) {
    sectionExcludedMoves[currentSection][currentSubsection].push(move + "+");
    sectionExcludedMoves[currentSection][currentSubsection].push(move + "#");
  }
}

function ranks(s: string): Array<Rank> {
  return _exp<Rank>(s);
}
function files(s: string): Array<Fil> {
  return _exp<Fil>(s);
}
function pieces(s: string): Array<Piece> {
  return _exp<Piece>(s);
}

function _exp<T extends Rank | Fil | Piece>(s: string): Array<T> {
  // a range like 'a-h', returns all letters from a to h
  if (s.includes("-")) {
    const [start, end] = s.split("-");
    return Array.from(
      { length: end.charCodeAt(0) - start.charCodeAt(0) + 1 },
      (_, i) => String.fromCharCode(start.charCodeAt(0) + i) as T
    );
  }
  if (s.includes(",")) {
    return s.split(",") as Array<T>;
  }
  throw new Error("Invalid expression");
}

type Fil = "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h";
type Rank = "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8";
type Piece = "Q" | "R" | "B" | "N" | "K";

/** Returns one or two adjacent files.
 * a -> b
 * b -> a,c
 * c -> b,d
 * */
function adjacent(file: Fil): Array<Fil> {
  if (file === "a") {
    return ["b"];
  }
  if (file === "h") {
    return ["g"];
  }
  return [offsetFile(file, -1)!, offsetFile(file, 1)!];
}

/** Offset the rank, but disallow out of bounds.
 * 1 + 1 -> 2
 * 5 - 2 -> 3
 * 7 + 2 -> null
 * */
function offsetRank(rank: Rank, off: number): Rank | undefined {
  const result = String.fromCharCode(rank.charCodeAt(0) + off) as Rank;
  if (result < "1" || result > "8") {
    return undefined;
  }
  return result;
}
/** Offset the file, but disallow out of bounds.
 * a + 1 -> b
 * e - 2 -> c
 * g + 2 -> null
 * */
function offsetFile(file: Fil, off: number): Fil | undefined {
  const result = String.fromCharCode(file.charCodeAt(0) + off) as Fil;
  if (result < "a" || result > "h") {
    return undefined;
  }
  return result;
}

/** Returns adjacent files up to 2 away (e.g. Knight's move away)
 * a -> b,c
 * b -> a,c,d
 * c -> a,b,d,e
 * */
function doubleadjacentfile(file: Fil): Array<Fil> {
  switch (file) {
    case "a":
      return ["b", "c"];
    case "b":
      return ["a", "c", "d"];
    case "c":
      return ["a", "b", "d", "e"];
    case "d":
      return ["b", "c", "e", "f"];
    case "e":
      return ["c", "d", "f", "g"];
    case "f":
      return ["d", "e", "g", "h"];
    case "g":
      return ["e", "f", "h"];
    case "h":
      return ["f", "g"];
  }
}

function doubleadjacentrank(rank: Rank): Array<Rank> {
  switch (rank) {
    case "1":
      return ["2", "3"];
    case "2":
      return ["1", "3", "4"];
    case "3":
      return ["1", "2", "4", "5"];
    case "4":
      return ["2", "3", "5", "6"];
    case "5":
      return ["3", "4", "6", "7"];
    case "6":
      return ["4", "5", "7", "8"];
    case "7":
      return ["5", "6", "8"];
    case "8":
      return ["6", "7"];
  }
}

/**
 * From a square like e5, return all [file, rank] pairs reachable from the source by a rook, excluding itself.
 * That's horizontal and vertical moves
 */
function rookReachable(file: Fil, rank: Rank): Array<[Fil, Rank]> {
  const result: Array<[Fil, Rank]> = [];
  for (const f of files("a-h")) {
    for (const r of ranks("1-8")) {
      if (f === file && r === rank) {
        continue; // skip ourself
      }
      if (f === file || r === rank) {
        result.push([f, r]);
      }
    }
  }
  return result;
}

/**
 * From a square like e5, return all [file, rank] pairs reachable from the source by a bishop, excluding itself.
 * That is, diagonal moves.
 */
function bishopReachable(file: Fil, rank: Rank): Array<[Fil, Rank]> {
  const result: Array<[Fil, Rank]> = [];
  for (const f of files("a-h")) {
    for (const r of ranks("1-8")) {
      if (f === file && r === rank) {
        continue; // skip ourself
      }
      if (
        Math.abs(f.charCodeAt(0) - file.charCodeAt(0)) ===
        Math.abs(r.charCodeAt(0) - rank.charCodeAt(0))
      ) {
        result.push([f, r]);
      }
    }
  }
  return result;
}

/**
 * From a square like e5, return all [file, rank] pairs reachable from the source by a queen, excluding itself.
 * That's horizontal, vertical, and diagonal moves.
 */
function queenReachable(file: Fil, rank: Rank): Array<[Fil, Rank]> {
  const result: Array<[Fil, Rank]> = [];
  for (const f of files("a-h")) {
    for (const r of ranks("1-8")) {
      if (f === file && r === rank) {
        continue; // skip ourself
      }
      if (
        f === file ||
        r === rank ||
        Math.abs(f.charCodeAt(0) - file.charCodeAt(0)) ===
          Math.abs(r.charCodeAt(0) - rank.charCodeAt(0))
      ) {
        result.push([f, r]);
      }
    }
  }
  return result;
}

/**
 * From a square like e5, return all [file, rank] pairs reachable from the source by a knight's move, excluding itself.
 * That's up to 8 squares.
 */
function knightReachable(file: Fil, rank: Rank): Array<[Fil, Rank]> {
  const result: Array<[Fil, Rank]> = [];
  [
    [1, 2],
    [2, 1],
    [-1, 2],
    [-2, 1],
    [1, -2],
    [2, -1],
    [-1, -2],
    [-2, -1],
  ].forEach(([dx, dy]) => {
    const f = offsetFile(file, dx);
    const r = offsetRank(rank, dy);
    if (f && r) {
      result.push([f, r]);
    }
  });
  return result;
}

///////////////////////////////////////////////////////////////////

/// Castles
section("Castles"); /////////////////////////////////////////////////////////////////////////////////////////////
emit("O-O");
emit("O-O-O");

section("Pawn"); /////////////////////////////////////////////////////////////////////////////////////////////
/// pawn pushes
for (const file of files("a-h")) {
  for (const rank of ranks("2-7")) {
    emit(`${file}${rank}`); // a1
  }
}

subsection("Pawn captures");
// can only come from adjacent squares. This includes en passant.
for (const file of files("a-h")) {
  for (const rank of ranks("2-7")) {
    for (const adj of adjacent(file)) {
      emit(`${file}x${adj}${rank}`); // axb1
    }
  }
}

subsection("Pawn promotions");
for (const file of files("a-h")) {
  for (const rank of ranks("1,8")) {
    for (const piece of pieces("Q,R,B,N")) {
      emit(`${file}${rank}=${piece}`); // a8=Q
    }
  }
}

subsection("Pawn capture promotions");
for (const file of files("a-h")) {
  for (const rank of ranks("1,8")) {
    for (const adj of adjacent(file)) {
      for (const piece of pieces("Q,R,B,N")) {
        emit(`${file}x${adj}${rank}=${piece}`); // axb8=Q
      }
    }
  }
}

section("Rook"); /////////////////////////////////////////////////////////////////////////////////////////////
for (const file of files("a-h")) {
  for (const rank of ranks("1-8")) {
    emit(`R${file}${rank}`); // Ra1
  }
}

subsection("Rook captures");
for (const file of files("a-h")) {
  for (const rank of ranks("1-8")) {
    emit(`Rx${file}${rank}`); // Rxa1
  }
}

subsection("Rook file disambiguated");
for (const sourceFile of files("a-h")) {
  for (const file of files("a-h")) {
    for (const rank of ranks("1-8")) {
      emit(`R${sourceFile}${file}${rank}`); // Raa1
      emit(`R${sourceFile}x${file}${rank}`); // Raxa1
    }
  }
}

subsection("Rook rank disambiguated");
for (const sourceRank of ranks("1-8")) {
  for (const file of files("a-h")) {
    for (const destRank of ranks("1-8")) {
      // [!] Rooks moving to 1 or 8 never need rank disambiguation.
      // R2a1 is never useful, since it's moving to an edge, there can't be another rook
      // "beyond" the edge, and there can't be another rook "in the way".
      if (destRank === "1" || destRank === "8") {
        exclude(`R${sourceRank}${file}${destRank}`); // R2a1
        exclude(`R${sourceRank}x${file}${destRank}`); // R2xa1
        continue;
      }
      // [!] Cannot rank disambiguate yourself
      // R3a3 is never useful, since it's already on '3'...
      // you'd always prefer using whatever file it came from.
      if (sourceRank === destRank) {
        exclude(`R${sourceRank}${file}${destRank}`); // R2a2
        exclude(`R${sourceRank}x${file}${destRank}`); // R2xa2
        continue;
      }
      // Rank moves may always be check/mate, because
      // the rook moves to a new square, and there is no requirement
      // that the other files on that target are blocked,
      // thus a king can be there to get checked/mated.
      emit(`R${sourceRank}${file}${destRank}`); // R1a2
      emit(`R${sourceRank}x${file}${destRank}`); // R1xa1
    }
  }
}
// rooks never require double disambiguation

section("Queen"); /////////////////////////////////////////////////////////////////////////////////////////////
for (const file of files("a-h")) {
  for (const rank of ranks("1-8")) {
    emit(`Q${file}${rank}`); // Qa1
  }
}

subsection("Queen captures");
for (const file of files("a-h")) {
  for (const rank of ranks("1-8")) {
    emit(`Qx${file}${rank}`); // Qxa1
  }
}

subsection("Queen file disambiguated");
for (const sourceFile of files("a-h")) {
  for (const file of files("a-h")) {
    for (const rank of ranks("1-8")) {
      emit(`Q${sourceFile}${file}${rank}`); // Qaa1
      emit(`Q${sourceFile}x${file}${rank}`); // Qaxa1
    }
  }
}

subsection("Queen rank disambiguated");
for (const destFile of files("a-h")) {
  for (const destRank of ranks("1-8")) {
    const diagonallyReachableSquares = bishopReachable(destFile, destRank);
    const daigonallyReachableRanks = new Set(
      diagonallyReachableSquares.map(([f, r]) => r)
    );
    for (const sourceRank of ranks("1-8")) {
      // [!] If you're moving to top or bottom edge,
      // then similar to a rook, you don't need rank disambiguation
      // for pieces on the same file for vertical movement.
      // There are still other files, but you must move diagonally
      // on those to reach the target by definition,
      // thus only diagonally reacahble ranks (or the same rank via horizontal moves)
      // are possible.
      // For example, a queen moving to e1 can't come from the 8th rank:
      //  - if it was on the e file, you'd not need disambiguation: Qe1
      //  - every other source file would require a diagonal move,
      //    but at most e1 can be reached by a5 or h4, so 6,7,8 are not possible source ranks.
      // But moving to e1 it could come from ranks 1 (via horizontal move), 2,3,4,5 (via diagonal moves)
      if (destRank === "1" || destRank === "8") {
        if (
          !(daigonallyReachableRanks.has(sourceRank) || sourceRank === destRank)
        ) {
          exclude(`Q${sourceRank}${destFile}${destRank}`); // Q8e1
          exclude(`Q${sourceRank}x${destFile}${destRank}`); // Q8xe1
          continue;
        }
      }
      // Every rank disambiguated move can be check/mate,
      // because the queen moves to a new square, and there is no requirement
      // that the other files on that target are blocked.
      emit(`Q${sourceRank}${destFile}${destRank}`); // Q2a3
      emit(`Q${sourceRank}x${destFile}${destRank}`); // Q2xa3
    }
  }
}

subsection("Queen double disambiguated");
for (const sourceFile of files("a-h")) {
  for (const sourceRank of ranks("1-8")) {
    for (const [destFile, destRank] of queenReachable(sourceFile, sourceRank)) {
      const move = `Q${sourceFile}${sourceRank}${destFile}${destRank}`;
      const capture = `Q${sourceFile}${sourceRank}x${destFile}${destRank}`;

      // [!] If the dest is on the edge (top/bottom/left/right),
      // then similar to the case in rank disambiguation, you can always use
      // file disambiguation to avoid double disambiguation when the source
      // is on the same file as the dest (for top/bottom, symmetrically for same rank for sides).
      // That is, the dest must be inset one square from the edge for all horizontal/vertical moves to be
      // able to be double disambiguations.
      if (
        (destRank === "1" || destRank === "8") &&
        (destFile === "a" || destFile === "h")
      ) {
        // moving to the corner
        // For example, a queen moving to a1 can't come from a2-a8, or b1-h1 to be a double disambiguation.
        //  - if it was on the a file, you'd not need double disambiguation, just file: Qaa1
        //  - if it was on the 1st rank, you'd not need double disambiguation, just rank: Q1a1
        //  - every other source file would require a diagonal move, but would be permissable double disambiguations.
        if (sourceFile === destFile || sourceRank === destRank) {
          exclude(move); // Qa8a1
          exclude(capture); // Qa8xa1
          continue;
        }
      } else if (destRank === "1" || destRank === "8") {
        // moving to the top or bottom
        // For example, a queen moving to e1 can't come from e2-e8 to be a double disambiguation.
        //  - if it was on the e file, you'd not need double disambiguation, just file: Qee1
        //  - moving on the same rank can require double disambiguation: Qa1e1
        //  - same for diagonals: Qd2e1
        if (sourceFile === destFile) {
          exclude(move); // Qe3e1
          exclude(capture); // Qe3xe1
          continue;
        }
      } else if (destFile === "a" || destFile === "h") {
        // moving to the left or right
        // For example, a queen moving to a4 can't come from b4-h4 to be a double disambiguation.
        //  - if it was on the 4 rank, you'd not need double disambiguation, just rank: Q4a4
        //  - moving on the same file can require double disambiguation: Qa1a4
        //  - same for diagonals: Qb3a4
        if (sourceRank === destRank) {
          exclude(move); // Qe3a3
          exclude(capture); // Qe3xa3
          continue;
        }
      }

      emit(move); // Qa1h8
      emit(capture); // Qa1xh8
    }
  }
}

section("Knight"); /////////////////////////////////////////////////////////////////////////////////////////////
for (const file of files("a-h")) {
  for (const rank of ranks("1-8")) {
    emit(`N${file}${rank}`); // Na1
  }
}

subsection("Knight captures");
for (const file of files("a-h")) {
  for (const rank of ranks("1-8")) {
    emit(`Nx${file}${rank}`); // Nxa1
  }
}

subsection("Knight file disambiguated");
for (const destFile of files("a-h")) {
  for (const destRank of ranks("1-8")) {
    // Knights can only be coming from one or two files away.
    // But every destination file has some valid source files.
    for (const sourceFile of doubleadjacentfile(destFile)) {
      emit(`N${sourceFile}${destFile}${destRank}`); // Nba1
      emit(`N${sourceFile}x${destFile}${destRank}`); // Nbxa1
    }
  }
}

subsection("Knight rank disambiguated");
for (const destFile of files("a-h")) {
  // [!] Knights moving to the 1st or 8th rank never need rank disambiguation.
  // To require rank disambiguation, there must be two squares on the same file
  // that can also move to that square. This requires the target square to be inset
  // by at least 1 square from the top/bottom.
  // Note: left/right sides are not a problem, e.g. N1a2 can come from c1 or c3.
  for (const destRank of ranks("2-7")) {
    // Knights can only be coming from one or two ranks away.
    for (const sourceRank of doubleadjacentrank(destRank)) {
      emit(`N${sourceRank}${destFile}${destRank}`); // N1b3
      emit(`N${sourceRank}x${destFile}${destRank}`); // N1xb3
    }
  }
}

subsection("Knight double disambiguated");
// [!] Double disambiguation with a knight requires 3 corners of a rectangle of knights.
// The knight move means this rectangle is 5x3, centered on the destination.
// The destination must be inset by at least 1 square from the top/bottom/left/right,
// or the "3" side of the rectangle will be cut off.
// So the outer rim can never be the destination of doubly disambiguated knight move.
// Additionally, for squares b2, b7, g2, g7, there's not enough space for the "5" side of the rectangle, either.
// So those destination squares never need double disambiguation.
for (const destFile of files("b-g")) {
  for (const destRank of ranks("2-7")) {
    for (const [sourceFile, sourceRank] of knightReachable(
      destFile,
      destRank
    )) {
      const move = `N${sourceFile}${sourceRank}${destFile}${destRank}`; // Na1b3
      const capture = `N${sourceFile}${sourceRank}x${destFile}${destRank}`; // Na1xb3
      if (["b", "g"].includes(destFile) && ["2", "7"].includes(destRank)) {
        exclude(move);
        exclude(capture);
        continue;
      }
      emit(move);
      emit(capture);
    }
  }
}

section("Bishop"); /////////////////////////////////////////////////////////////////////////////////////////////
for (const file of files("a-h")) {
  for (const rank of ranks("1-8")) {
    emit(`B${file}${rank}`); // Ba1
  }
}

subsection("Bishop captures");
for (const file of files("a-h")) {
  for (const rank of ranks("1-8")) {
    emit(`Bx${file}${rank}`); // Bxa1
  }
}

subsection("Bishop file disambiguated");
for (const destFile of files("a-h")) {
  for (const destRank of ranks("1-8")) {
    // as long as some bishop move could reach the destination,
    // it could be the source of the file disambiguated move.
    const bishopReachableSquares = bishopReachable(destFile, destRank);
    const reachableFiles = new Set(bishopReachableSquares.map(([f, r]) => f));
    for (const sourceFile of reachableFiles) {
      const move = `B${sourceFile}${destFile}${destRank}`; // Bea2
      const capture = `B${sourceFile}x${destFile}${destRank}`; // Bexa2
      // [!] The corners of the board never require file diambiguation.
      // If the destination is a corner, there is only one diagonal
      // that can reach it. Thus, no other bishop can be on the same file.
      if (["a", "h"].includes(destFile) && ["1", "8"].includes(destRank)) {
        exclude(move);
        exclude(capture);
        continue;
      }
      emit(move);
      emit(capture);
    }
  }
}

/** From a given rank, find adjacent ranks in both directions up until either one of the edges.
 * For example, from rank 2, find ranks 1 and 3.
 * From rank 3, find ranks 1, 2, 4, 5
 * From rank 5, find ranks 2, 3, 4, 6, 7, 8
 */
function ranksToEdge(destRank: Rank): Array<Rank> {
  const rankNum = destRank.charCodeAt(0) - "0".charCodeAt(0);
  if (rankNum >= 5) {
    // second half of the board, return ranks up to 8
    const distance = 8 - rankNum;
    let result: Array<Rank> = [];
    for (let i = 1; i <= distance; i++) {
      result.push(String.fromCharCode("0".charCodeAt(0) + rankNum - i) as Rank);
      result.push(String.fromCharCode("0".charCodeAt(0) + rankNum + i) as Rank);
    }
    return result;
  }

  const distance = rankNum - 1;
  let result: Array<Rank> = [];
  for (let i = 1; i <= distance; i++) {
    result.push(String.fromCharCode("0".charCodeAt(0) + rankNum - i) as Rank);
    result.push(String.fromCharCode("0".charCodeAt(0) + rankNum + i) as Rank);
  }
  return result;
}

subsection("Bishop rank disambiguated");
for (const destFile of files("a-h")) {
  for (const destRank of ranks("2-7")) {
    // [!] Rank disambiguation requires two bishops on the same file could reach the
    // destination. This means the destination must be inset by at least 1 square from the top/bottom,
    // but also only certain sourceRanks are possible.
    // For example, if the dest is on rank 3,  only ranks 1,2,4,5 can be source ranks,
    // since there must be two bishops on the same file, so they must have compatible ranks.
    // This is encoded in "ranksToEdge" (which handles corners not being possible already).
    const validRanks = ranksToEdge(destRank);
    for (const sourceRank of ranks("1-8")) {
      const move = `B${sourceRank}${destFile}${destRank}`; // Baa1
      const capture = `B${sourceRank}x${destFile}${destRank}`; // Baxa1
      if (!validRanks.includes(sourceRank)) {
        exclude(move);
        exclude(capture);
        continue;
      }
      emit(move);
      emit(capture);
    }
  }
}

/**
 * Return every dim x dim square on the chessboard.
 * Return array of squares, with the center square and the 4 corners.
 * Only odd dimensions are allowed, since it must be odd to have a center square.
 * Used for bishop double disambiguation, where bishops must be in a square.
 */
function arrangeSquare(
  dim: number
): Array<{ center: [Fil, Rank]; corners: Array<[Fil, Rank]> }> {
  if (dim % 2 === 0) {
    throw new Error("Only odd dimensions allowed");
  }
  if (dim < 3 || dim > 7) {
    throw new Error("Only dimensions 3-7 allowed");
  }
  let results: Array<{ center: [Fil, Rank]; corners: Array<[Fil, Rank]> }> = [];
  for (let left = 0; left <= 8 - dim; left++) {
    for (let top = 0; top <= 8 - dim; top++) {
      const halfdim = dim / 2;
      const cf = String.fromCharCode("a".charCodeAt(0) + left + halfdim) as Fil;
      const cr = String.fromCharCode("1".charCodeAt(0) + top + halfdim) as Rank;
      const center: [Fil, Rank] = [cf, cr];
      const corners: Array<[Fil, Rank]> = [
        [offsetFile(cf, 1 - halfdim)!, offsetRank(cr, 1 - halfdim)!],
        [offsetFile(cf, halfdim)!, offsetRank(cr, 1 - halfdim)!],
        [offsetFile(cf, 1 - halfdim)!, offsetRank(cr, halfdim)!],
        [offsetFile(cf, halfdim)!, offsetRank(cr, halfdim)!],
      ];
      results.push({ center, corners });
    }
  }
  return results;
}

subsection("Bishop double disambiguated");
// [!] Double disambiguation for bishops can be thought of as a square of bishops.
// You must have two bishops on the same row, and two on the same file, and one bishop shared between them.
// This necessitates a 3x3, 5x5, or 7x7 square, with 3 bishops on the edges.
// For each square, the center of the square is a valid destination, and each corner is a valid source.
for (const dim of [3, 5, 7]) {
  for (const { center, corners } of arrangeSquare(dim)) {
    const [destFile, destRank] = center;
    for (const [sourceFile, sourceRank] of corners) {
      const move = `B${sourceFile}${sourceRank}${destFile}${destRank}`; // Ba1c3
      const capture = `B${sourceFile}${sourceRank}x${destFile}${destRank}`; // Ba1xc3
      emit(move);
      emit(capture);
    }
  }
}

section("King"); /////////////////////////////////////////////////////////////////////////////////////////////
for (const file of files("a-h")) {
  for (const rank of ranks("1-8")) {
    emit(`K${file}${rank}`); // Ka1
  }
}
// It's tempting to think corner king moves may not be possible to be check/mate, since king checks/mates must
// be discovered attacks (kings can't directly threaten the other king).
// However, since Kings moves are never disambiguated,
// only the destination matters.
// Thus, e.g., Ka1 can be check/mate if king is coming from b2, it can reveal e.g. queen on a2.
// Same for every other corner. So every king move can be check/mate.

subsection("King captures");
for (const file of files("a-h")) {
  for (const rank of ranks("1-8")) {
    emit(`Kx${file}${rank}`); // Kxa1
  }
}

//////////////////////////////////////////

function println(s: string = "") {
  return console.log(s);
}

function red(s: string) {
  return `\x1b[31m${s}\x1b[0m`;
}

function green(s: string) {
  return `\x1b[32m${s}\x1b[0m`;
}
function gray(s: string) {
  return `\x1b[90m${s}\x1b[0m`;
}

const context = 8;

const shortOutput = process.argv.includes("--short");
const plain = process.argv.includes("--plain");
if (plain) {
  for (const [_, sectionValue] of Object.entries(sectionMoves)) {
    for (const [_, subsectionValue] of Object.entries(sectionValue)) {
      process.stdout.write(subsectionValue.join("\n") + "\n");
    }
  }
} else {
  for (const [sectionName, sectionValue] of Object.entries(sectionMoves)) {
    const total = Object.values(sectionValue).reduce(
      (acc, v) => acc + v.length,
      0
    );
    println(red(`# ${sectionName}  (${total})`));
    for (const [subsectionName, subsectionValue] of Object.entries(
      sectionValue
    )) {
      println(green(`## ${subsectionName}  (${subsectionValue.length})`));
      println(writeMoves(subsectionValue));

      const excluded = sectionExcludedMoves[sectionName][subsectionName];
      if (excluded.length > 0) {
        println(
          gray(`### Excluded from ${subsectionName}  (${excluded.length})`)
        );
        println(gray(writeMoves(excluded)));
      }
    }
    println();
  }
}

function writeMoves(moves: Array<string>) {
  if (shortOutput && moves.length > 2 * context) {
    return (
      moves.slice(0, context).join("  ") +
      " ... " +
      moves.slice(-context).join("  ")
    );
  } else {
    return moves.join("  ");
  }
}
