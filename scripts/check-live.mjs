#!/usr/bin/env node
/**
 * 本番 (ar.ldas.jp) と旧 URL の転送を、実際に HTTP で叩いて確かめる。
 * 配布後・独自ドメインの設定後に手元で実行する: npm run test:live
 *
 * 見ること:
 *   1. 新ホストのトップが 200 で、canonical が新ホストを指す
 *   2. ページが読む相対の資産 (favicon 等)・privacy.html・robots.txt・sitemap.xml・
 *      サンプルのコレクション JSON が 200
 *   3. 存在しないパスが 404、http は https へ転送
 *   4. 旧 github.io/iiif-ar-ios/<path>?<query> が同じパス・クエリのまま新ホストへ 301
 *      (App Store に登録済みのプライバシーポリシー URL もここで確かめる)
 */
const NEW = 'https://ar.ldas.jp';
const OLD = 'https://nakamura196.github.io/iiif-ar-ios';

const errors = [];
let passed = 0;
const ok = (cond, msg) => (cond ? passed++ : errors.push(msg));
const get = (url, opts = {}) => fetch(url, { redirect: 'manual', ...opts });

// 1, 2
const top = await get(NEW + '/');
ok(top.status === 200, `${NEW}/ → ${top.status} (200 のはず)`);
const html = await top.text();
const canonical = html.match(/<link rel="canonical" href="([^"]+)"/)?.[1];
ok(canonical === NEW + '/', `canonical が ${canonical} (${NEW}/ のはず)`);
const assets = [...html.matchAll(/\s(?:href|src)="([a-z][^":]*\.[a-z]+)"/g)].map((m) => m[1]);
ok(assets.length > 0, 'トップから相対の資産参照が見つからない');
for (const path of [...new Set(assets), 'privacy.html', 'robots.txt', 'sitemap.xml', 'sample_collection.json', 'sample_collection_v1.json']) {
  const r = await get(`${NEW}/${path}`);
  ok(r.status === 200, `${NEW}/${path} → ${r.status}`);
}

// 3
{
  const r = await get(NEW + '/no-such-page/');
  ok(r.status === 404, `存在しないページが ${r.status} (404 のはず)`);
  const h = await get('http://ar.ldas.jp/privacy.html?lang=en');
  const loc = h.headers.get('location');
  ok(h.status === 301 && loc === `${NEW}/privacy.html?lang=en`, `http → ${h.status} ${loc} (301 ${NEW}/privacy.html?lang=en のはず)`);
}

// 4
for (const path of ['/', '/privacy.html', '/icon.png', '/sample_collection.json', '/?lang=en']) {
  const r = await get(OLD + path);
  const loc = r.headers.get('location');
  ok(r.status === 301 && loc === NEW + path, `${OLD}${path} → ${r.status} ${loc} (301 ${NEW + path} のはず)`);
}

if (errors.length) {
  console.error(`NG: ${errors.length} 件 (OK ${passed} 件)`);
  for (const e of errors) console.error('  ' + e);
  process.exit(1);
}
console.log(`OK: ${passed} 件`);
