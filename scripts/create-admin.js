require("dotenv").config();
const bcrypt = require("bcryptjs");
const db = require("../src/db");
const readline = require("readline");

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const ask = q => new Promise(resolve => rl.question(q, resolve));
function askHidden(question) {
  return new Promise(resolve => {
    if (!process.stdin.isTTY || typeof process.stdin.setRawMode !== "function") {
      const fallback = readline.createInterface({ input: process.stdin, output: process.stdout });
      fallback.question(`${question} (terminal cannot hide input): `, answer => { fallback.close(); resolve(answer); });
      return;
    }
    const input = process.stdin;
    let answer = "";
    process.stdout.write(question);
    input.setRawMode(true);
    input.setEncoding("utf8");
    input.resume();
    const onData = chunk => {
      for (const char of chunk) {
        if (char === "\u0003") {
          input.removeListener("data", onData);
          input.setRawMode(false);
          input.pause();
          process.stdout.write("\nAdmin creation cancelled.\n");
          process.exit(130);
        } else if (char === "\r" || char === "\n") {
          input.removeListener("data", onData);
          input.setRawMode(false);
          input.pause();
          process.stdout.write("\n");
          resolve(answer);
          return;
        } else if (char === "\u0008" || char === "\u007f") {
          answer = answer.slice(0, -1);
        } else if (char >= " ") {
          answer += char;
        }
      }
    };
    input.on("data", onData);
  });
}
(async () => {
  const username = (await ask("Choose admin username: ")).trim();
  rl.close();
  const password = await askHidden("Choose a strong admin password (input hidden): ");
  if (!/^[a-zA-Z0-9_.-]{3,40}$/.test(username)) {
    console.error("Username must be 3-40 chars: letters, numbers, dot, underscore or hyphen.");
    rl.close(); process.exit(1);
  }
  if (password.length < 12) {
    console.error("Use at least 12 characters for the admin password.");
    rl.close(); process.exit(1);
  }
  const hash = await bcrypt.hash(password, 12);
  try {
    db.prepare("INSERT INTO admins (username, password_hash) VALUES (?, ?)").run(username, hash);
    console.log("Admin created. Keep your password private.");
  } catch (e) {
    console.error(e.message.includes("UNIQUE") ? "That username already exists." : "Could not create admin.");
    process.exitCode = 1;
  } finally { rl.close(); db.close(); }
})();
