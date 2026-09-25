/**
 * 公開 URL (https://ar.ldas.jp) を決めている箇所を固定する。
 * ドメインを変えるときは、ここと docs/ の該当ファイル、App Store Connect の
 * マーケティング URL・プライバシーポリシー URL (docs/appstore-metadata.md) を同時に直す。
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const SITE = 'https://ar.ldas.jp';
const read = (p) => readFileSync(new URL(`../docs/${p}`, import.meta.url), 'utf8');
const html = read('index.html');
const attr = (re) => html.match(re)?.[1];

test('CNAME はホスト名 1 行だけ (GitHub Pages の独自ドメイン)', () => {
  assert.equal(read('CNAME'), 'ar.ldas.jp\n');
});

test('canonical と og:url が新ホストの / を指す', () => {
  assert.equal(attr(/<link rel="canonical" href="([^"]+)"/), `${SITE}/`);
  assert.equal(attr(/property="og:url" content="([^"]+)"/), `${SITE}/`);
});

test('og:image と twitter:image が新ホストの icon.png を指す', () => {
  const imgs = [...html.matchAll(/(?:property="og:image"|name="twitter:image")\s+content="([^"]+)"/g)];
  assert.equal(imgs.length, 2);
  for (const m of imgs) assert.equal(m[1], `${SITE}/icon.png`);
});

test('フッタのプライバシーポリシーは実在する privacy.html を指す', () => {
  assert.match(html, /<a href="privacy\.html">/);
});

test('App Store に登録する URL の控えが新ホストを指す', () => {
  const md = read('appstore-metadata.md');
  assert.match(md, new RegExp(`^${SITE}/$`, 'm'));
  assert.match(md, new RegExp(`^${SITE}/privacy\\.html$`, 'm'));
  assert.doesNotMatch(md, /github\.io\/iiif-ar-ios/);
});

test('robots.txt が新ホストの sitemap を示す', () => {
  assert.match(read('robots.txt'), new RegExp(`^Sitemap: ${SITE}/sitemap\\.xml$`, 'm'));
});

test('sitemap.xml はトップとプライバシーポリシー', () => {
  const locs = [...read('sitemap.xml').matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
  assert.deepEqual(locs, [`${SITE}/`, `${SITE}/privacy.html`]);
});

test('サイト内の参照は相対パスだけ (/ 始まりはサブパス配信で壊れる)', () => {
  for (const page of ['index.html', 'privacy.html']) {
    const rootAbs = [...read(page).matchAll(/\s(?:href|src)="(\/[^/][^"]*)"/g)].map((m) => m[1]);
    assert.deepEqual(rootAbs, [], page);
  }
});
