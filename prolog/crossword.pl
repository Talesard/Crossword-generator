#!/usr/bin/swipl
% for easy run on linux as a script, (chmod +x is required)
% how to run: ./crossword.pl <words filename> <Crossword size> <iter count>

% why limit iterations instead of using find all - too long and 4+ GB of memory

:- set_prolog_flag(stack_limit, 4_294_967_296). % we need more RAM for stack :)
:- style_check(-singleton). % disable warnings
:- use_module(library(dialect/sicstus)). % for file input
:- initialization main.



main :-
    current_prolog_flag(argv, Argv),
    getArgs(Argv, WordsFilename, CrosswordSize, Attempts),
    open(WordsFilename, read, Str),
    readFile(Str, WordsList),
    close(Str),
    firstWordVariants(FirstLocations), % init start locations
    getBestCrossoword(Attempts, WordsList, FirstLocations, CrosswordSize, [], -1),
    halt. % it's like exit()


% list of string CL args to numbers
getArgs(Argv, WordsFilenameOut, CrosswordSizeOut, AttemptsOut):-
    Argv = [WordsFilenameOut, CrosswordSizeArg, AttemptsArg],
    atom_number(CrosswordSizeArg, CrosswordSizeOut),
    atom_number(AttemptsArg, AttemptsOut).


iteration(WordsList, FirstLocations, CrosswordSize, UsedWordsOut, CriteriaOut) :-
    shuffleList(WordsList, WordsListTmp),
    shuffleList(FirstLocations, FirstLocationsTmp),
    member(FirstLocation, FirstLocationsTmp),
    crossword(CrosswordSize, WordsListTmp, FirstLocation, UsedWordsOut, CriteriaOut).


crossword(CrosswordSize, Words, FirstLocation, UsedWordsOut, CriteriaOut) :-
    generateCrossword(CrosswordSize, Words, FirstLocation, _Crossword, UsedWordsOut),
    getCriteriaValue(UsedWordsOut, CriteriaOut).


getBestCrossoword(0, _, _, _, _, _).
getBestCrossoword(N, WordsList, FirstLocations, CrosswordSize, BestPlaced, BestCriteria):-
    N>0,
    % writeln(N),
    iteration(WordsList, FirstLocations, CrosswordSize, UsedWordsOut, CriteriaOut),
    (
        CriteriaOut > BestCriteria -> ( % if
            TmpCriteria = CriteriaOut,
            TmpUsedWords = UsedWordsOut,
            write('Improve to '), write(TmpCriteria), write(' on iter '), writeln(N)
        ) ; ( % else
            TmpCriteria = BestCriteria,
            TmpUsedWords = BestPlaced
        )
    ),
    (
        N == 1 -> ( % if
            fillCrosswordWithUsedWords(TmpUsedWords, CrosswordSize, Crossword),
            writeCrossword(Crossword, CrosswordSize)
        ) ; ( % else
            true
        )
    ),
    M is N-1,
    getBestCrossoword(M, WordsList, FirstLocations, CrosswordSize, TmpUsedWords, TmpCriteria).


getCriteriaValue([], 0).
getCriteriaValue(UsedWords, Criteria):-
    maplist(nth1(3), UsedWords, PlacedAllPos),
    flatten(PlacedAllPos, PlacedAllPosFlat),
    length(PlacedAllPosFlat, PlacedAllPosFlatLen),
    list_to_set(PlacedAllPosFlat, PlacedAllPosSet),
    length(PlacedAllPosSet, PlacedAllPosSetLen),
    Criteria is PlacedAllPosFlatLen - PlacedAllPosSetLen.


readFile(Stream,[]) :-
    at_end_of_stream(Stream).


readFile(Stream,[X|L]) :-
    \+ at_end_of_stream(Stream),
    read_line(Stream, Line),
    string_to_list(X, Line),
    readFile(Stream,L).


generateCrossword(CrosswordSize, Words, FirstLocation, Crossword, UsedWords) :-
    getCleanCrossword(CrosswordSize, Crossword1),
    getFirstCharPos(FirstLocation, CrosswordSize, FirstCharPos, StartDir),
    placeAllWords(Words, [], CrosswordSize, FirstCharPos, StartDir, Crossword1, Crossword, UsedWords).


placeAllWords([], P, _, _, _, Crossword, Crossword, P).
placeAllWords(Words, UsedWords, CrosswordSize, FirstCharPos, Direction, CrosswordInput, CrosswordOut, UsedWordsOut) :-
    member(Word, Words),
    atom_chars(Word, Chars),
    delete(Chars, ' ', Chars2),
    length(Chars2, WordLen),
    getIntersectionWordToConnect(Chars2, WordLen, UsedWords, CrosswordSize, FirstCharPos, Direction),
    placeWord(Word, Chars2, WordLen, FirstCharPos, Direction, CrosswordSize, CrosswordInput, Used, Crossword1),
    removeFromList(Word, Words, RemWords),
    placeAllWords(RemWords, [Used|UsedWords], CrosswordSize, _FirstCharPos, _Direction, Crossword1, CrosswordOut, UsedWordsOut).



getIntersectionWordToConnect(_Chars, _WordLen, [], _CrosswordSize, _FirstCharPos, _Direction).
getIntersectionWordToConnect(Chars, WordLen, UsedWords, CrosswordSize, FirstCharPos, Direction) :-
    member([_, UsedChars, _, UsedDirection, _, UsedFirstCharPos], UsedWords),
    intersection(Chars, UsedChars, Intersections),
    list_to_set(Intersections, IntersectionsSet),
    member(Val, IntersectionsSet),
    position(Val, UsedChars, PPos),
    position(Val, Chars, Pos),
    getWordIndex(UsedDirection, CrosswordSize, PPos, UsedFirstCharPos, PNum),
    switchDirection(UsedDirection, Direction),
    getFirstCharPos(Direction, CrosswordSize, Pos, PNum, FirstCharPos),
    isNotOutOfCrosswordRange(Direction, FirstCharPos, WordLen, CrosswordSize).


placeWord(Word, Chars, WordLen, FirstCharPos, Direction, CrosswordSize, CrosswordInput, Used, CrosswordOut) :-
    checkPreviosCell(Direction, FirstCharPos, CrosswordSize, CrosswordInput),
    placeChars(Chars, FirstCharPos, Direction, CrosswordSize, WordPositions, CrosswordInput, CrosswordOut),
    Used = [Word, Chars, WordPositions, Direction, WordLen, FirstCharPos].


checkPreviosCell(Direction, CellIndex, CrosswordSize, Crossword) :-
    (
     isFirstCell(Direction, CellIndex, CrosswordSize)
    ;
     getPreviosCell(Direction, CellIndex, CrosswordSize, Prev),
     get_assoc(Prev, Crossword, freeCell)
    ), !.


checkNextCell(Direction, CellIndex, CrosswordSize, Crossword) :-
    getPreviosCell(Direction, CellIndex, CrosswordSize, Prev),
    (
     isLastCell(Direction, Prev, CrosswordSize)
    ;
     get_assoc(CellIndex, Crossword, freeCell)
    ), !.


placeChars([], CellIndex, Direction, CrosswordSize, [], Crossword, Crossword) :- 
    checkNextCell(Direction, CellIndex, CrosswordSize, Crossword).


placeChars([L|Ls], CellIndex, Direction, CrosswordSize, [CellIndex|RestWordPositions], CrosswordInput, CrosswordOut) :-
    get_assoc(CellIndex, CrosswordInput, X),
    (
     X == L,
     Crossword1 = CrosswordInput
    ;
     X == freeCell,
     isNearestNeighboursFree(Direction, CellIndex, CrosswordSize, CrosswordInput),
     put_assoc(CellIndex, CrosswordInput, L, Crossword1)
    ), !,
    getNextCell(Direction, CellIndex, CrosswordSize, Num2),
    placeChars(Ls, Num2, Direction, CrosswordSize, RestWordPositions, Crossword1, CrosswordOut).


isNearestNeighboursFree(vertical, CellIndex, CrosswordSize, Crossword) :-
    N1 is CellIndex - 1,
    N2 is CellIndex + 1,
    M is CellIndex mod CrosswordSize,
    (
     M == 0 -> get_assoc(N1, Crossword, freeCell)
    ;
     M == 1 -> get_assoc(N2, Crossword, freeCell)
    ;
     get_assoc(N1, Crossword, freeCell),
     get_assoc(N2, Crossword, freeCell)
    ), !.


isNearestNeighboursFree(horizontal, CellIndex, CrosswordSize, Crossword) :-
    N1 is CellIndex - CrosswordSize,
    N2 is CellIndex + CrosswordSize,
    LastCell is (CrosswordSize * CrosswordSize),
    (
     N1 =< 0 -> get_assoc(N2, Crossword, freeCell)
    ;
     N2 > LastCell -> get_assoc(N1, Crossword, freeCell)
    ;
     get_assoc(N1, Crossword, freeCell),
     get_assoc(N2, Crossword, freeCell)
    ), !.


direction(vertical).
direction(horizontal).


switchDirection(vertical, horizontal).
switchDirection(horizontal, vertical).


firstWordVariants([u_l_horizontal, u_l_vertical, u_r, d_l]).


getFirstCharPos(u_l_horizontal, _CrosswordSize, 1, horizontal).
getFirstCharPos(u_l_vertical, _CrosswordSize, 1, vertical).
getFirstCharPos(u_r, CrosswordSize, CrosswordSize, vertical).
getFirstCharPos(d_l, CrosswordSize, FirstCharPos, horizontal) :- 
    FirstCharPos is (CrosswordSize * CrosswordSize) - (CrosswordSize - 1).


isNotOutOfCrosswordRange(horizontal, FirstCharPos, WordLen, CrosswordSize) :- 
    M is FirstCharPos mod CrosswordSize,
    M \== 0,
    Space is CrosswordSize - (M - 1),
    WordLen =< Space.


isNotOutOfCrosswordRange(vertical, FirstCharPos, WordLen, CrosswordSize) :- 
     EndNum is FirstCharPos + (CrosswordSize * (WordLen - 1)),
     EndNum =< CrosswordSize * CrosswordSize.


isFirstCell(horizontal, CellIndex, Length) :-
    1 is CellIndex mod Length.


isFirstCell(vertical, CellIndex, Length) :-
    CellIndex =< Length.


isLastCell(horizontal, CellIndex, Length) :-
    0 is CellIndex mod Length.


isLastCell(vertical, CellIndex, Length) :-
    CellIndex >= (Length - 1) * Length.


getPreviosCell(horizontal, CellIndex, _Length, Prev) :-
    Prev is CellIndex - 1.


getPreviosCell(vertical, CellIndex, Length, Prev) :-
    Prev is CellIndex - Length.


getNextCell(horizontal, CellIndex, _Length, Next) :-
    Next is CellIndex + 1.


getNextCell(vertical, CellIndex, Length, Next) :-
    Next is CellIndex + Length.


getFirstCharPos(horizontal, _CrosswordSize, PPos, WordIndex, FirstCharPos) :-
    FirstCharPos is WordIndex - (PPos - 1).


getFirstCharPos(vertical, CrosswordSize, PPos, WordIndex, FirstCharPos) :-
    FirstCharPos is WordIndex - (CrosswordSize * (PPos - 1)).


getWordIndex(horizontal, _CrosswordSize, WordPosition, WordFirstCharPos, WordIndex) :-
    WordIndex is  WordFirstCharPos + (WordPosition - 1).


getWordIndex(vertical, CrosswordSize, WordPosition, WordFirstCharPos, WordIndex) :-
    WordIndex is  WordFirstCharPos + (CrosswordSize * (WordPosition - 1)).


newFreeCell(CellIndex, CellIndex-freeCell).


getCleanCrossword(CrosswordSize, Crossword) :-
    CellsCount is CrosswordSize * CrosswordSize,
    numlist(1, CellsCount, Cells),
    maplist(newFreeCell, Cells, TupleList),
    list_to_assoc(TupleList, Crossword).


position(X, List, Pos) :- getPositionX(List, X, 1, Pos).


getPositionX([], _, _, _) :- false.
getPositionX([X|_], X, Pos, Pos).
getPositionX([_|Ys], X, N, Pos) :-
    N2 is N + 1,
    getPositionX(Ys, X, N2, Pos).


removeFromList(Y,[X|Xs],[X|Tail]) :-
    Y \== X,
    removeFromList(Y,Xs,Tail).


removeFromList(X,[X|Xs],Xs) :- !.
removeFromList(_,[],[]).


shuffleList([], []) :- !.
shuffleList(List, [ElemHead|ElemTail]) :-
    getRandomElementOfList(List, ElemHead),
    delete(List, ElemHead, NewList),
    shuffleList(NewList, ElemTail).


getRandomElementOfList(List, Choosed) :-
    length(List, Length),
    Index is random(Length),
    nth0(Index, List, Choosed).


fillCrosswordWithUsedWords(UsedWords, CrosswordSize, Crossword) :-
    getCleanCrossword(CrosswordSize, NewCrossword),
    addAllUsedWordsToCrossword(UsedWords, NewCrossword, Crossword).


addAllUsedWordsToCrossword([], Crossword, Crossword).
addAllUsedWordsToCrossword([WordsHead|WordsTail], CrosswordInput, CrosswordOut) :-
    WordsHead = [_, Chars, WordPositions, Direction, _, FirstCharPos],
    addCharsOfUsedWordToCrossword(Chars, WordPositions, Direction, FirstCharPos, CrosswordInput, Crossword1),
    addAllUsedWordsToCrossword(WordsTail, Crossword1, CrosswordOut).


addCharsOfUsedWordToCrossword([], [], _, _, Crossword, Crossword).
addCharsOfUsedWordToCrossword([CharsHead|CharsTail], [WordPosHead|WordPosTail], Direction, FirstCharPos, CrosswordInput, CrosswordOut) :-
    get_assoc(WordPosHead, CrosswordInput, X),
    (
     X == freeCell -> ( Direction == horizontal, Val = [CellIndex-x, CharsHead, _, _]
     ;
      Direction == vertical, Val = [x-CellIndex, CharsHead, _, _]
     ), !
    ;
     X = [A-D,CharsHead,_,_],
     (
      Direction == horizontal, Val = [CellIndex-D, CharsHead, _, _]
     ;
      Direction == vertical, Val = [A-CellIndex, CharsHead, _, _]
     ), !
    ),
    put_assoc(WordPosHead, CrosswordInput, Val, Crossword1),
    addCharsOfUsedWordToCrossword(CharsTail, WordPosTail, Direction, FirstCharPos, Crossword1, CrosswordOut).


writeCrossword(Crossword, Length) :-
    assoc_to_list(Crossword, List),
    writeCrosswordList(List, Length).


writeCrosswordList([], _).
writeCrosswordList([Index-Cell|Tail], Length) :-
    ( Cell == freeCell -> ( write('.') ) ; ( Cell = [_,L,_,_], write(L)) ),
    write(' '),
    M is Index mod Length,
    ( M == 0 -> nl ; true),
    writeCrosswordList(Tail, Length).