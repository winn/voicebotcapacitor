import fs from 'node:fs';
import path from 'node:path';

const configPath = path.resolve('ios/App/App/capacitor.config.json');
const raw = fs.readFileSync(configPath, 'utf8');
const data = JSON.parse(raw);
const list = Array.isArray(data.packageClassList) ? data.packageClassList : [];
if (!list.includes('ChatComposerPlugin')) {
  list.push('ChatComposerPlugin');
  data.packageClassList = list;
  fs.writeFileSync(configPath, JSON.stringify(data, null, 2) + '\n');
  console.log('Added ChatComposerPlugin to capacitor.config.json');
} else {
  console.log('ChatComposerPlugin already present');
}
