This is a lil' code to analyze chess .pgn files, with the goal of finding the "rarest" move in chess.

That is, the rarest move notation (standard algebraic notation) given a large number of input games (e.g. every rated game from lichess) in pgn format.

However, since there are many moves that never happen, this is moreso counting and categorizing moves of various types rather than finding one specific rare move.

## Running

This was written using zig 0.12.0.

This analysis is done in 2 separate phases (and hence programs)

1. Read pgn data from stdin, count moves, store in a move string => int mapping, save data to a temporary .result.json file
   - We also save games that contain rare moves to use as examples
   - We also save some statistics like total games processed and total bytes processed
2. Read multiple .result.json files, merge into one map of move => count. Perform analysis on these moves.

- Phase 1 can be run with `zig build run -- collect < games.pgn > result.json` or `zstdcat ./compressed/lichess_20XX-YY.pgn.zst | zig build run -- collect > result.json` if using compressed data from lichess.
  - Note: you should use `-Doptimize=ReleaseFast` here since this is a slow process for recent months of data.
  - This parses ~100k games / sec on my machine, but running multiple instances of this script allows processing multiple months in parallel. I could get ~400k games / sec this way. Recent months from Lichess are ~30GB compressed, which takes ~15 min to process at 100k games / sec.
- Phase 2 can be run with `zig build run -- analyze partialResults/`.
  - This loads all `.result.json` games in the `partialResults/` folder, and prints analysis out to stdout.

## Possible Moves

Additionally, this repo contains scripts to generate all possible legal moves
in standard algebraic notation. I may expand on this in the future.

To generate all the moves, use:

```
bun run ./possibleMoves.ts --plain
```

Or use `--short` instead of `--plain` to see a summary instead of all moves.

## About

Note that pgn files used in my analysis are not included in this repo, because I used 1500 Gigabytes of them.
This repo _does_ include the counts of encountered moves from the pgn files I analyzed (the .result.json files from the _collect_ phase).

The interesting stuff happens in the analyze phase.
It counts how many moves are of different forms, like promotions, disambiguations, etc.
We also look for the percent "coverage" we get, by comparing how many moves of different pieces we see compared to how many we could theoretically see.
See src/analyze.zig for the logic that counts how many possible moves there are.

There's also a couple of scripts here to help compute how many possible moves there are using a python chess library. (this is used to find the % coverage)

Why is this written in zig? Just for funzies

## Results

I analyzed all of the [rated game data from lichess](https://database.lichess.org/#standard_games) between July 2014 and December 2023.

This analysis included **342,490,585,837 moves** from **5,163,425,477 games**, from **9.4TB** of uncompressed pgn game data.

Note that before July 2014, there seems to be some bug in the Lichess game data that reports some moves
not in their most simple form, for example,
there are some doubly disambiguated rook moves (this is never necessary)
and some doubly disambiguated knight moves that could be expressed as rank or file disambiguations.
Hence data before July 2014 is excluded. It's a measely 8,247,741 games, or 0.1% of total games excluded.

I also looked at a few more smaller datasets but they're so few games I excluded them from the analysis.

4 categories of rare moves are:

- Doubly Disambiguated Queen capture checkmates, like Qc3xd4#
- Rank-Disambiguated Bishop capture checkmates, like B3xd4#
- Doubly Disambiguated Knight Capture Checkmates like Na1xb3# (I've never seen an example of this)
- Doubly Disambiguated Bishop Capture Checkmates like Bb3xc4# (I've never seen an example of this)

Each of these has less-rare variants like non-capture mates, capture with check, etc.

Running the analysis with the included partialResults gives this output:

```
Reading data from lichess_db_standard_rated_2020-08.result.json
  > Games:     71,131,606  Moves:  4,760,057,166      Bytes: 0.2TB, BytesFromGames: 0.1TB      unique moves: 16,415, interesting games: 1
Reading data from lichess_db_standard_rated_2021-11.result.json
  > Games:     86,886,214  Moves:  5,762,124,818      Bytes: 0.2TB, BytesFromGames: 0.2TB      unique moves: 16,654, interesting games: 7

...

Reading data from lichess_db_standard_rated_2017-12.result.json
  > Games:     16,191,145  Moves:  1,090,745,082      Bytes: 34.3GB, BytesFromGames: 28.7GB      unique moves: 15,037, interesting games: 0
Reading data from lichess_db_standard_rated_2018-07.result.json
  > Games:     21,027,590  Moves:  1,411,274,965      Bytes: 44.8GB, BytesFromGames: 37.0GB      unique moves: 15,152, interesting games: 0

wrote combined result data to results.json

Total Moves:     342,490,585,837
Unique Moves:             21,373
Total Games:       5,163,425,477
Data processed (uncompressed): 11.3TB
Data processed (uncompressed, excluding annotations): 9.4TB

Possible legal moves: (x3 to include check and checkmate)
Pawn:       308 (   924)
Rook:     1,824 ( 5,472)
Knight:   1,248 ( 3,744)
Bishop:   1,720 ( 5,064)
Queen:    5,088 (14,928)
King:       128 (   384)

There are 10,318 possible moves without including check or checkmate
There are 30,518 possible moves including check or checkmate


342,490,585,837 moves analyzed

♟ Pawn moves:   95,553,301,110 (27.90%)  -     924 unique (100.00% coverage)
♚ King moves:   37,122,221,520 (10.84%)  -     382 unique (99.48% coverage)
♜ Rook moves:   48,055,626,263 (14.03%)  -   5,295 unique (96.77% coverage)
♞ Knight moves: 59,629,230,254 (17.41%)  -   2,909 unique (77.70% coverage)
♛ Queen moves:  42,061,708,229 (12.28%)  -   9,216 unique (61.74% coverage)
♝ Bishop moves: 52,179,069,156 (15.24%)  -   2,641 unique (52.15% coverage)

         23.87% of all moves are captures
          7.13% of all moves are checks
          0.40% of all moves are checkmates
          2.45% of all moves are capture checks
          0.13% of all moves are capture checkmates

    905,956,248 promotions (0.26% of moves)
    885,814,970 ♛ Queen promotions  (97.78% of promotions)
     12,174,403 ♜ Rook promotions   (1.34% of promotions)
      5,473,818 ♞ Knight promotions (0.60% of promotions)
      2,493,057 ♝ Bishop promotions (0.28% of promotions)

  6,640,013,855 O-O    moves
  1,221,306,721 O-O-O  moves
      2,052,673 O-O+   moves
     26,005,452 O-O-O+ moves
         16,754 O-O#   moves
         33,850 O-O-O# moves

     47,111,628 ♟ Pawn mates (0.0137556%)
        660,664 potential en passant pawn mates (0.0001929%)
         16,754 short castle mates (0.0000049%)
         33,850 long castle mates (0.0000099%)

    880,774,212 ♛ Queen mates   (0.25717% of all moves) (64.82% of mates)
    344,839,104 ♜ Rook mates    (0.10069% of all moves) (25.38% of mates)
     47,111,628 ♟ Pawn mates    (0.01376% of all moves) (3.47% of mates)
     43,678,167 ♝ Bishop mates  (0.01275% of all moves) (3.21% of mates)
     42,067,185 ♞ Knight mates  (0.01228% of all moves) (3.10% of mates)
        353,344 ♚ King mates    (0.00010% of all moves) (0.03% of mates)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ♛ Queen ♛ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 42,061,708,229 Queen total (12.281128290%)
 13,639,117,622 Queen total captures (3.982333584%)
  8,705,551,293 Queen total checks (2.541836667%)
    880,774,212 Queen total mates (0.257167423%)
  2,721,775,678 Queen total capture checks (0.794700874%)
    331,056,415 Queen total capture mates (0.096661464%)

    167,885,606 Queen file disambiguations (0.049019043%)
     12,105,866 Queen file disambiguations captures (0.003534657%)
     81,439,886 Queen file disambiguations checks (0.023778723%)
     38,694,497 Queen file disambiguations mates (0.011297974%)
      5,574,810 Queen file disambiguations capture checks (0.001627726%)
      2,984,112 Queen file disambiguations capture mates (0.000871298%)

     15,893,376 Queen rank disambiguations (0.004640529%)
      1,736,300 Queen rank disambiguations captures (0.000506963%)
      7,635,454 Queen rank disambiguations checks (0.002229391%)
      2,837,596 Queen rank disambiguations mates (0.000828518%)
        824,270 Queen rank disambiguations capture checks (0.000240669%)
        403,989 Queen rank disambiguations capture mates (0.000117956%)

         63,199 Queen double disambiguations (0.000018453%)
            597 Queen double disambiguations captures (0.000000174%)
         13,991 Queen double disambiguations checks (0.000004085%)
         10,557 Queen double disambiguations mates (0.000003082%)
            199 Queen double disambiguations capture checks (0.000000058%)
            179 Queen double disambiguations capture mates (0.000000052%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ♝ Bishop ♝ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 52,179,069,156 Bishop total (15.235183481%)
 15,082,611,403 Bishop total captures (4.403803207%)
  3,404,834,022 Bishop total checks (0.994139449%)
     43,678,167 Bishop total mates (0.012753100%)
  1,569,400,318 Bishop total capture checks (0.458231666%)
     12,032,846 Bishop total capture mates (0.003513336%)

        189,259 Bishop file disambiguations (0.000055260%)
          5,044 Bishop file disambiguations captures (0.000001473%)
         30,622 Bishop file disambiguations checks (0.000008941%)
          4,277 Bishop file disambiguations mates (0.000001249%)
            694 Bishop file disambiguations capture checks (0.000000203%)
            109 Bishop file disambiguations capture mates (0.000000032%)

         22,035 Bishop rank disambiguations (0.000006434%)
            607 Bishop rank disambiguations captures (0.000000177%)
            383 Bishop rank disambiguations checks (0.000000112%)
             74 Bishop rank disambiguations mates (0.000000022%)
            116 Bishop rank disambiguations capture checks (0.000000034%)
             26 Bishop rank disambiguations capture mates (0.000000008%)

            665 Bishop double disambiguations (0.000000194%)
              0 Bishop double disambiguations captures (0.000000000%)
              3 Bishop double disambiguations checks (0.000000001%)
              1 Bishop double disambiguations mates (0.000000000%)
              0 Bishop double disambiguations capture checks (0.000000000%)
              0 Bishop double disambiguations capture mates (0.000000000%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ♞ Knight ♞ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 59,629,230,254 Knight total (17.410472790%)
 13,976,641,351 Knight total captures (4.080883367%)
  3,649,343,699 Knight total checks (1.065531098%)
     42,067,185 Knight total mates (0.012282727%)
  1,361,943,120 Knight total capture checks (0.397658557%)
      7,976,620 Knight total capture mates (0.002329004%)

  3,229,888,533 Knight file disambiguations (0.943059070%)
    303,724,314 Knight file disambiguations captures (0.088681069%)
     38,452,511 Knight file disambiguations checks (0.011227319%)
        470,315 Knight file disambiguations mates (0.000137322%)
      8,525,010 Knight file disambiguations capture checks (0.002489122%)
         51,465 Knight file disambiguations capture mates (0.000015027%)

    154,952,344 Knight rank disambiguations (0.045242804%)
     11,417,031 Knight rank disambiguations captures (0.003333531%)
      4,118,533 Knight rank disambiguations checks (0.001202524%)
         66,601 Knight rank disambiguations mates (0.000019446%)
        569,808 Knight rank disambiguations capture checks (0.000166372%)
          5,654 Knight rank disambiguations capture mates (0.000001651%)

          1,973 Knight double disambiguations (0.000000576%)
              3 Knight double disambiguations captures (0.000000001%)
            544 Knight double disambiguations checks (0.000000159%)
             45 Knight double disambiguations mates (0.000000013%)
              1 Knight double disambiguations capture checks (0.000000000%)
              0 Knight double disambiguations capture mates (0.000000000%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ♜ Rook ♜ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 48,055,626,263 Rook total (14.031225456%)
 13,191,210,090 Rook total captures (3.851554068%)
  6,869,586,799 Rook total checks (2.005773905%)
    344,839,104 Rook total mates (0.100685718%)
  2,126,943,004 Rook total capture checks (0.621022326%)
     84,667,929 Rook total capture mates (0.024721243%)

  6,989,702,805 Rook file disambiguations (2.040845236%)
    302,772,646 Rook file disambiguations captures (0.088403202%)
    189,322,324 Rook file disambiguations checks (0.055278110%)
     11,951,245 Rook file disambiguations mates (0.003489511%)
     28,804,596 Rook file disambiguations capture checks (0.008410332%)
      2,955,532 Rook file disambiguations capture mates (0.000862953%)

    383,615,672 Rook rank disambiguations (0.112007654%)
     37,238,224 Rook rank disambiguations captures (0.010872773%)
     63,244,905 Rook rank disambiguations checks (0.018466173%)
      6,869,381 Rook rank disambiguations mates (0.002005714%)
      2,578,022 Rook rank disambiguations capture checks (0.000752728%)
         91,201 Rook rank disambiguations capture mates (0.000026629%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ♚ King ♚ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 37,122,221,520 King total (10.838902748%)
  4,176,599,794 King total captures (1.219478715%)
     28,208,571 King total checks (0.008236306%)
        353,344 King total mates (0.000103169%)
      2,006,264 King total capture checks (0.000585787%)
         13,677 King total capture mates (0.000003993%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ♟ Pawn ♟ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 95,553,301,110 Pawn total (27.899540910%)
 21,678,618,613 Pawn total captures (6.329697665%)
  1,722,700,697 Pawn total checks (0.502992131%)
     47,111,628 Pawn total mates (0.013755598%)
    600,753,460 Pawn total capture checks (0.175407291%)
      5,493,971 Pawn total capture mates (0.001604123%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ♟ → * Promotion ♟ → * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    905,956,248 Promotion total (0.264520044%)
     56,999,902 Promotion total captures (0.016642765%)
    248,429,170 Promotion total checks (0.072536058%)
     25,397,680 Promotion total mates (0.007415585%)
     31,202,938 Promotion total capture checks (0.009110597%)
      2,947,683 Promotion total capture mates (0.000860661%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ♟ → ♛ Promotion to Queen ♟ → ♛ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    885,814,970 Promotion to Queen total (0.258639217%)
     55,300,109 Promotion to Queen total captures (0.016146461%)
    243,744,053 Promotion to Queen total checks (0.071168103%)
     23,427,409 Promotion to Queen total mates (0.006840307%)
     30,320,462 Promotion to Queen total capture checks (0.008852933%)
      2,805,060 Promotion to Queen total capture mates (0.000819018%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ♟ → ♛ Promotion to Bishop ♟ → ♛ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      2,493,057 Promotion to Bishop total (0.000727920%)
        192,314 Promotion to Bishop total captures (0.000056152%)
        759,651 Promotion to Bishop total checks (0.000221802%)
         25,203 Promotion to Bishop total mates (0.000007359%)
         36,117 Promotion to Bishop total capture checks (0.000010545%)
            628 Promotion to Bishop total capture mates (0.000000183%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ♟ → ♛ Promotion to Knight ♟ → ♛ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      5,473,818 Promotion to Knight total (0.001598239%)
        627,566 Promotion to Knight total captures (0.000183236%)
      2,000,154 Promotion to Knight total checks (0.000584003%)
         30,414 Promotion to Knight total mates (0.000008880%)
        347,448 Promotion to Knight total capture checks (0.000101447%)
          3,370 Promotion to Knight total capture mates (0.000000984%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ♟ → ♛ Promotion to Rook ♟ → ♛ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     12,174,403 Promotion to Rook total (0.003554668%)
        879,913 Promotion to Rook total captures (0.000256916%)
      1,925,312 Promotion to Rook total checks (0.000562150%)
      1,914,654 Promotion to Rook total mates (0.000559038%)
        498,911 Promotion to Rook total capture checks (0.000145671%)
        138,625 Promotion to Rook total capture mates (0.000040476%)
```
