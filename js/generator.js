class Crossword {
    constructor(gridSize, words) {
        this.gridSize = gridSize;
        this.grid = Array.from(Array(this.gridSize), () => new Array(this.gridSize).fill(null));
        this.words = words.sort((w1, w2) => w1.length - w2.length);
        this.charIds = {};
    }

    // generate crossword
    generate = () => {
        const startDir = Math.floor(Math.random() * 2) ? 'h' : 'v';
        const currentWord = this.words[0];
        let x = Math.floor(this.gridSize / 2) - (startDir === 'h') * Math.floor(currentWord.length / 2);
        let y = Math.floor(this.gridSize / 2) - (startDir === 'v') * Math.floor(currentWord.length / 2);
        this.placeWord(currentWord, y, x, startDir);

        const remWordsLists = [];
        remWordsLists.push(this.words.slice(1));
        let isSuccessfulPlaced;
        for (let g = 0; g < remWordsLists.length; g++) {
            isSuccessfulPlaced = false;
            for (let i = 0; i < remWordsLists[g].length; i++) {
                const currentWord = remWordsLists[g][i];
                const isPlaced = this.getPosForNewWord(currentWord);
                if (!isPlaced) {
                    if (remWordsLists.length - 1 === g) remWordsLists.push([]);
                    remWordsLists[g + 1].push(currentWord);
                } else {
                    this.placeWord(currentWord, isPlaced.row, isPlaced.col, isPlaced.direction);
                    isSuccessfulPlaced = true;
                }
            }
            if (!isSuccessfulPlaced) break;
        }
        return isSuccessfulPlaced ? this.grid : null;
    };

    // place word depending on the direction
    placeWord = (word, row, col, direction) => {
        if (direction === 'h') {
            for (let x = col, i = 0; x < col + word.length; x++, i++) {
                this.addWordToGrid(word, i, row, x);
            }
        } else if (direction === 'v') {
            for (let y = row, i = 0; y < row + word.length; y++, i++) {
                this.addWordToGrid(word, i, y, col);
            }
        }
    };

    // add word to this.grid
    addWordToGrid = (word, charIndex, y, x) => {
        const char = word[charIndex];
        if (this.grid[y][x] === null) {
            this.grid[y][x] = char;
            if (!this.charIds[char]) this.charIds[char] = [];
            this.charIds[char].push({ row: y, col: x });
        }
    };

    // check is cell free or same char
    canCharBePlaced = (char, row, col) => {
        if (this.grid[row][col] === null) return 0;
        if (this.grid[row][col] === char) return 1;
        return false;
    };

    // check all conditions for place word
    canWordBePlaced = (word, row, col, direction) => {
        if (row < 0 || row >= this.grid.length || col < 0 || col >= this.grid[row].length) return false;
        let intersections = 0;
        if (direction === 'h') {
            if (col + word.length > this.grid[row].length) return false;
            if (col - 1 >= 0 && this.grid[row][col - 1] != null) return false;
            if (col + word.length < this.grid[row].length && this.grid[row][col + word.length] != null) return false;

            for (let y = row - 1, x = col, i = 0; y >= 0 && x < col + word.length; x++, i++) {
                const isEmpty = this.grid[y][x] === null;
                const isIntersection = this.grid[row][x] != null && this.grid[row][x] === word[i];
                const isPlaceable = isEmpty || isIntersection;
                if (!isPlaceable) return false;
            }

            for (let y = row + 1, x = col, i = 0; y < this.grid.length && x < col + word.length; x++, i++) {
                const isEmpty = this.grid[y][x] === null;
                const isIntersection = this.grid[row][x] != null && this.grid[row][x] === word[i];
                const isPlaceable = isEmpty || isIntersection;
                if (!isPlaceable) return false;
            }

            for (let x = col, i = 0; x < col + word.length; x++, i++) {
                const result = this.canCharBePlaced(word[i], row, x);
                if (result === false) return false;
                intersections += result;
            }
        } else if (direction === 'v') {
            if (row + word.length > this.grid.length) return false;
            if (row - 1 >= 0 && this.grid[row - 1][col] != null) return false;
            if (row + word.length < this.grid.length && this.grid[row + word.length][col] != null ) return false;

            for (let x = col - 1, y = row, i = 0; x >= 0 && y < row + word.length; y++, i++) {
                const isEmpty = this.grid[y][x] === null;
                const isIntersection = this.grid[y][col] != null && this.grid[y][col] === word[i];
                const isPlaceable = isEmpty || isIntersection;
                if (!isPlaceable) return false;
            }

            for (let x = col + 1, y = row, i = 0; y < row + word.length && x < this.grid[y].length; y++, i++) {
                const isEmpty = this.grid[y][x] === null;
                const isIntersection = this.grid[y][col] != null && this.grid[y][col] === word[i];
                const isPlaceable = isEmpty || isIntersection;
                if (!isPlaceable) return false;
            }

            for (let y = row, i = 0; y < row + word.length; y++, i++) {
                const result = this.canCharBePlaced(word.charAt(i, 1), y, col);
                if (result === false) return false;
                intersections += result;
            }
        }
        return intersections;
    };

    // get all positions and random choose one of them
    getPosForNewWord = (word) => {
        const positions = [];
        for (let i = 0; i < word.length; i++) {
            const locs = this.charIds[word[i]];
            if (!locs) continue;
            for (let j = 0; j < locs.length; j++) {
                const currLoc = locs[j];
                const y = currLoc.row;
                const x = currLoc.col;
                const intersectionHor = this.canWordBePlaced(word, y, x - i, 'h');
                const intersectionVer = this.canWordBePlaced(word, y - i, x, 'v');
                if (intersectionHor !== false) positions.push({intersections: intersectionHor, row: y, col: x - i, direction: 'h'});
                if (intersectionVer !== false) positions.push({intersections: intersectionVer, row: y - i, col: x, direction: 'v',});
            }
        }
        return positions.length === 0 ? false : positions[Math.floor(Math.random() * positions.length)];
    };

    // conversion to a beautiful look
    getCharMatrix = () => {
        const matrix = Array.from(Array(this.gridSize), () =>
            new Array(this.gridSize).fill('')
        );
        for (let i = 0; i < this.grid.length; i++) {
            for (let j = 0; j < this.grid[i].length; j++) {
                if (this.grid[i][j] === null) {
                    matrix[i][j] = '.';
                } else {
                    matrix[i][j] = this.grid[i][j];
                }
            }
        }
        return matrix;
    };

    // check coords is not out of range
    isNotOutOfRange = (x, y) => x >= 0 && y >= 0 && x < this.gridSize && y < this.gridSize;

    // check cell is not empty
    isNotEmpty = (x, y) => this.grid[x][y] !== null;

    // check grid[x][y] is intersection
    isIntersection = (x, y) => {
        if (this.isNotEmpty(x, y)) {
            let rd, ru, ld, lu;
            rd = this.isNotOutOfRange(x + 1, y) && this.isNotEmpty(x + 1, y) && this.isNotOutOfRange(x, y + 1) && this.isNotEmpty(x, y + 1);
            ru = this.isNotOutOfRange(x - 1, y) && this.isNotEmpty(x - 1, y) && this.isNotOutOfRange(x, y + 1) && this.isNotEmpty(x, y + 1);
            ld = this.isNotOutOfRange(x, y - 1) && this.isNotEmpty(x, y - 1) && this.isNotOutOfRange(x + 1, y) && this.isNotEmpty(x + 1, y);
            lu = this.isNotOutOfRange(x, y - 1) && this.isNotEmpty(x, y - 1) && this.isNotOutOfRange(x - 1, y) && this.isNotEmpty(x - 1, y);
            return rd || ru || ld || lu;
        }
        return false;
    };

    // get intersection count
    getCriteriaValue = () => {
        let counter = 0;
        for (let i = 0; i < this.grid.length; i++) {
            for (let j = 0; j < this.grid[i].length; j++) {
                if (this.isIntersection(i, j)) counter++;
            }
        }
        return counter;
    };

    // print matrix
    print = () => {
        const matrix = this.getCharMatrix();
        for (let i = 0; i < this.grid.length; i++) {
            console.log(matrix[i].join(' '));
        }
    };
}

// find best crossowrd using stochastic method
findBestCrossword = (words, gridSize, maxIters) => {
    let bestCrossword = new Crossword(gridSize, words);
    bestCrossword.generate();
    let bestCriteria = bestCrossword.getCriteriaValue();
    for (let i = 1; i < maxIters; i++) {
        const crossword = new Crossword(gridSize, words);
        crossword.generate();
        const criteria = crossword.getCriteriaValue();
        if (criteria > bestCriteria) {
            console.log(`Improve to ${criteria} on iter ${i}`);
            bestCrossword = crossword;
            bestCriteria = criteria;
        }
    }
    return { crossword: bestCrossword, criteria: bestCriteria };
};

exports.Crossword = Crossword;
exports.findBestCrossword = findBestCrossword;
