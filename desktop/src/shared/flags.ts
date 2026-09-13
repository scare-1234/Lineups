/**
 * Converts an API-Football nationality string ("Brazil", "England", …) into a flag emoji.
 * Unknown countries return null so the UI can fall back to plain text.
 */

const SUBDIVISIONS: Record<string, string> = {
  england: 'gbeng',
  scotland: 'gbsct',
  wales: 'gbwls',
};

/** Football nations as API-Football spells them, plus the aliases it also returns. */
const REGION_CODES: Record<string, string> = {
  afghanistan: 'AF', albania: 'AL', algeria: 'DZ', andorra: 'AD', angola: 'AO',
  'antigua and barbuda': 'AG', argentina: 'AR', armenia: 'AM', aruba: 'AW',
  australia: 'AU', austria: 'AT', azerbaijan: 'AZ', bahamas: 'BS', bahrain: 'BH',
  bangladesh: 'BD', barbados: 'BB', belarus: 'BY', belgium: 'BE', belize: 'BZ',
  benin: 'BJ', bermuda: 'BM', bhutan: 'BT', bolivia: 'BO',
  bosnia: 'BA', 'bosnia and herzegovina': 'BA', botswana: 'BW', brazil: 'BR',
  bulgaria: 'BG', 'burkina faso': 'BF', burundi: 'BI', cambodia: 'KH',
  cameroon: 'CM', canada: 'CA', 'cape verde': 'CV', 'cape verde islands': 'CV',
  'central african republic': 'CF', chad: 'TD', chile: 'CL', china: 'CN',
  'china pr': 'CN', colombia: 'CO', comoros: 'KM', congo: 'CG',
  'congo dr': 'CD', 'democratic republic of congo': 'CD', 'costa rica': 'CR',
  croatia: 'HR', cuba: 'CU', curacao: 'CW', cyprus: 'CY',
  'czech republic': 'CZ', czechia: 'CZ', denmark: 'DK', djibouti: 'DJ',
  dominica: 'DM', 'dominican republic': 'DO', ecuador: 'EC', egypt: 'EG',
  'el salvador': 'SV', 'equatorial guinea': 'GQ', eritrea: 'ER', estonia: 'EE',
  eswatini: 'SZ', ethiopia: 'ET', 'faroe islands': 'FO', fiji: 'FJ',
  finland: 'FI', france: 'FR', gabon: 'GA', gambia: 'GM', georgia: 'GE',
  germany: 'DE', ghana: 'GH', gibraltar: 'GI', greece: 'GR', grenada: 'GD',
  guadeloupe: 'GP', guatemala: 'GT', guinea: 'GN', 'guinea-bissau': 'GW',
  guyana: 'GY', haiti: 'HT', honduras: 'HN', 'hong kong': 'HK', hungary: 'HU',
  iceland: 'IS', india: 'IN', indonesia: 'ID', iran: 'IR', iraq: 'IQ',
  ireland: 'IE', 'republic of ireland': 'IE', israel: 'IL', italy: 'IT',
  'ivory coast': 'CI', "cote d'ivoire": 'CI', jamaica: 'JM', japan: 'JP',
  jordan: 'JO', kazakhstan: 'KZ', kenya: 'KE', kosovo: 'XK', kuwait: 'KW',
  kyrgyzstan: 'KG', laos: 'LA', latvia: 'LV', lebanon: 'LB', lesotho: 'LS',
  liberia: 'LR', libya: 'LY', liechtenstein: 'LI', lithuania: 'LT',
  luxembourg: 'LU', madagascar: 'MG', malawi: 'MW', malaysia: 'MY',
  maldives: 'MV', mali: 'ML', malta: 'MT', martinique: 'MQ',
  mauritania: 'MR', mauritius: 'MU', mexico: 'MX', moldova: 'MD',
  monaco: 'MC', mongolia: 'MN', montenegro: 'ME', montserrat: 'MS',
  morocco: 'MA', mozambique: 'MZ', myanmar: 'MM', namibia: 'NA',
  nepal: 'NP', netherlands: 'NL', 'new caledonia': 'NC', 'new zealand': 'NZ',
  nicaragua: 'NI', niger: 'NE', nigeria: 'NG', 'north korea': 'KP',
  'north macedonia': 'MK', macedonia: 'MK', 'northern ireland': 'GB',
  norway: 'NO', oman: 'OM', pakistan: 'PK', palestine: 'PS', panama: 'PA',
  'papua new guinea': 'PG', paraguay: 'PY', peru: 'PE', philippines: 'PH',
  poland: 'PL', portugal: 'PT', 'puerto rico': 'PR', qatar: 'QA',
  reunion: 'RE', romania: 'RO', russia: 'RU', rwanda: 'RW',
  'saint kitts and nevis': 'KN', 'saint lucia': 'LC',
  'saint vincent and the grenadines': 'VC', samoa: 'WS', 'san marino': 'SM',
  'saudi arabia': 'SA', senegal: 'SN', serbia: 'RS', 'sierra leone': 'SL',
  singapore: 'SG', slovakia: 'SK', slovenia: 'SI', somalia: 'SO',
  'south africa': 'ZA', 'south korea': 'KR', 'korea republic': 'KR',
  'south sudan': 'SS', spain: 'ES', 'sri lanka': 'LK', sudan: 'SD',
  suriname: 'SR', sweden: 'SE', switzerland: 'CH', syria: 'SY',
  tahiti: 'PF', taiwan: 'TW', tajikistan: 'TJ', tanzania: 'TZ',
  thailand: 'TH', togo: 'TG', 'trinidad and tobago': 'TT', tunisia: 'TN',
  turkey: 'TR', turkiye: 'TR', turkmenistan: 'TM', uganda: 'UG',
  ukraine: 'UA', 'united arab emirates': 'AE', 'united kingdom': 'GB',
  'united states': 'US', usa: 'US', uruguay: 'UY', uzbekistan: 'UZ',
  venezuela: 'VE', vietnam: 'VN', yemen: 'YE', zambia: 'ZM', zimbabwe: 'ZW',
};

function normalise(value: string): string {
  return value
    .trim()
    .normalize('NFD')
    // Strip combining marks so "Cote d'Ivoire" matches an accented spelling.
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

/** Builds a 🇧🇷-style flag from an ISO 3166-1 alpha-2 code. */
export function regionalIndicator(code: string): string | null {
  const letters = code.trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(letters)) return null;
  const base = 0x1f1e6;
  return String.fromCodePoint(
    base + (letters.charCodeAt(0) - 65),
    base + (letters.charCodeAt(1) - 65),
  );
}

/** Builds a 🏴󠁧󠁢󠁥󠁮󠁧󠁿-style flag from an ISO 3166-2 subdivision code. */
export function subdivisionFlag(code: string): string | null {
  const lower = code.trim().toLowerCase();
  if (!/^[a-z0-9]{3,6}$/.test(lower)) return null;
  const tags: number[] = [];
  for (const character of lower) {
    const code = character.codePointAt(0);
    if (code === undefined) return null;
    tags.push(0xe0000 + code);
  }
  return String.fromCodePoint(0x1f3f4, ...tags, 0xe007f);
}

export function flagEmoji(nationality: string | null | undefined): string | null {
  if (!nationality) return null;
  const key = normalise(nationality);
  if (key.length === 0) return null;

  const subdivision = SUBDIVISIONS[key];
  if (subdivision) return subdivisionFlag(subdivision);

  const code = REGION_CODES[key];
  return code ? regionalIndicator(code) : null;
}

/** Flag + name, or just the name when no flag exists for that country. */
export function flagLabel(nationality: string | null | undefined, fallback = 'Unknown'): string {
  const name = (nationality ?? '').trim();
  if (name.length === 0) return fallback;
  const flag = flagEmoji(name);
  return flag ? `${flag} ${name}` : name;
}
