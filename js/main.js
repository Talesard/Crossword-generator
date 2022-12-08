// how to run: node main.js <words filename> <сrossword size> <iter count>

const generator = require('./generator');
const fs = require('fs').promises;

const readWords = async (filename) => {
  const data = await fs.readFile(filename);
  return data.toString().replaceAll('\r', '').split('\n');
};

const main = async () => {
  const [wordsFilename, gridSize, maxIters] = process.argv.slice(2);
  const words = await readWords(wordsFilename);
  const res = generator.findBestCrossword(words, +gridSize, +maxIters);
  res.crossword.print();
  console.log(`\nCriteria: ${res.criteria}`);
};

main();
