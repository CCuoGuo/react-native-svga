/**
 * MIT License
 *
 * Copyright (C) 2025 Huawei Device Co., Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */


const fs = require('fs');
const JSON5 = require('json5');
const path = require('path');

const templatePath = path.join(
  __dirname,
  '..',
  'harmony',
  'build-profile.template.json5',
);
const existingProfilePath = path.join(
  __dirname,
  '..',
  'harmony',
  'build-profile.json5',
);

if (fs.existsSync(existingProfilePath)) {
  let existingProfile = JSON5.parse(
    fs.readFileSync(existingProfilePath, 'utf-8'),
  );
  let template = JSON5.parse(fs.readFileSync(templatePath, 'utf-8'));
  let signingConfigs =
    existingProfile.app && existingProfile.app.signingConfigs;

  existingProfile = {...template};

  if (signingConfigs) {
    existingProfile.app.signingConfigs = signingConfigs;
  }

  fs.writeFileSync(
    existingProfilePath,
    JSON5.stringify(existingProfile, null, 2),
  );
} else {
  // File doesn't exist, create a copy from the template
  fs.copyFileSync(templatePath, existingProfilePath);
}