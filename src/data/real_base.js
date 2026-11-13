/* ============================================================
   DATA / REAL — nations & the top 5 leagues (2025/26 season).
   Ratings are the developer's own estimates. Club badges in-game
   are original colour-matched designs, not official crests.
   ============================================================ */
const REAL = { clubs: {}, order: [] };
// code: [name, flagType, ...colours]
const REAL_NATIONS = {
  ENG: ['England', 'cross', '#ffffff', '#cf142b'], SCO: ['Scotland', 'saltire', '#005eb8', '#ffffff'], WAL: ['Wales', 'h2', '#ffffff', '#00b140'], NIR: ['Northern Ireland', 'cross', '#ffffff', '#cf142b'], IRL: ['Ireland', 'v3', '#169b62', '#ffffff', '#ff883e'],
  ESP: ['Spain', 'h3w', '#aa151b', '#f1bf00', '#aa151b'], FRA: ['France', 'v3', '#0055a4', '#ffffff', '#ef4135'], GER: ['Germany', 'h3', '#000000', '#dd0000', '#ffce00'], ITA: ['Italy', 'v3', '#009246', '#ffffff', '#ce2b37'],
  POR: ['Portugal', 'v2p', '#006600', '#ff0000'], NED: ['Netherlands', 'h3', '#ae1c28', '#ffffff', '#21468b'], BEL: ['Belgium', 'v3', '#000000', '#fdda24', '#ef3340'], CRO: ['Croatia', 'h3', '#ff0000', '#ffffff', '#171796'],
  SUI: ['Switzerland', 'swiss', '#da291c', '#ffffff'], AUT: ['Austria', 'h3', '#ed2939', '#ffffff', '#ed2939'], DEN: ['Denmark', 'nordic', '#c8102e', '#ffffff', '#ffffff'], SWE: ['Sweden', 'nordic', '#006aa7', '#fecc00', '#fecc00'],
  NOR: ['Norway', 'nordic', '#ba0c2f', '#ffffff', '#00205b'], FIN: ['Finland', 'nordic', '#ffffff', '#002f6c', '#002f6c'], ISL: ['Iceland', 'nordic', '#02529c', '#ffffff', '#dc1e35'], POL: ['Poland', 'h2', '#ffffff', '#dc143c'],
  CZE: ['Czechia', 'czech', '#ffffff', '#d7141a', '#11457e'], SVK: ['Slovakia', 'h3', '#ffffff', '#0b4ea2', '#ee1c25'], SVN: ['Slovenia', 'h3', '#ffffff', '#005da4', '#ed1c24'], SRB: ['Serbia', 'h3', '#c6363c', '#0c4076', '#ffffff'],
  HUN: ['Hungary', 'h3', '#ce2939', '#ffffff', '#477050'], UKR: ['Ukraine', 'h2', '#0057b7', '#ffd700'], TUR: ['Türkiye', 'crescent', '#e30a17', '#ffffff'], GRE: ['Greece', 'h5', '#0d5eaf', '#ffffff', '#0d5eaf', '#ffffff', '#0d5eaf'],
  GEO: ['Georgia', 'cross', '#ffffff', '#ff0000'], ALB: ['Albania', 'solid', '#e41e20'], KOS: ['Kosovo', 'solid', '#244aa5'], BIH: ['Bosnia & Herzegovina', 'solid', '#002395'], MNE: ['Montenegro', 'solid', '#c40308'],
  MKD: ['North Macedonia', 'circle', '#d20000', '#ffe600'], ROU: ['Romania', 'v3', '#002b7f', '#fcd116', '#ce1126'], BUL: ['Bulgaria', 'h3', '#ffffff', '#00966e', '#d62612'], ARM: ['Armenia', 'h3', '#d90012', '#0033a0', '#f2a800'],
  LUX: ['Luxembourg', 'h3', '#ed2939', '#ffffff', '#00a1de'], CYP: ['Cyprus', 'solid', '#ffffff'], ISR: ['Israel', 'h3', '#ffffff', '#0038b8', '#ffffff'], LTU: ['Lithuania', 'h3', '#fdb913', '#006a44', '#c1272d'],
  BRA: ['Brazil', 'diamond', '#009c3b', '#ffdf00', '#002776'], ARG: ['Argentina', 'h3', '#74acdf', '#ffffff', '#74acdf'], URU: ['Uruguay', 'h5', '#ffffff', '#0038a8', '#ffffff', '#0038a8', '#ffffff'], COL: ['Colombia', 'h3w', '#fcd116', '#003893', '#ce1126'],
  ECU: ['Ecuador', 'h3w', '#ffdd00', '#034ea2', '#ed1c24'], PAR: ['Paraguay', 'h3', '#d52b1e', '#ffffff', '#0038a8'], CHI: ['Chile', 'h2', '#ffffff', '#d52b1e'], VEN: ['Venezuela', 'h3', '#ffcc00', '#00247d', '#cf142b'],
  PER: ['Peru', 'v3', '#d91023', '#ffffff', '#d91023'], MEX: ['Mexico', 'v3', '#006847', '#ffffff', '#ce1126'], USA: ['United States', 'usa', '#b22234', '#ffffff', '#3c3b6e'], CAN: ['Canada', 'v3c', '#ff0000', '#ffffff', '#ff0000'],
  JAM: ['Jamaica', 'saltire', '#009b3a', '#fed100'], HAI: ['Haiti', 'h2', '#00209f', '#d21034'], CUW: ['Curaçao', 'solid', '#002b7f'], SUR: ['Suriname', 'h3', '#377e3f', '#ffffff', '#b40a2d'],
  NGA: ['Nigeria', 'v3', '#008751', '#ffffff', '#008751'], SEN: ['Senegal', 'v3', '#00853f', '#fdef42', '#e31b23'], GHA: ['Ghana', 'h3', '#ce1126', '#fcd116', '#006b3f'], CIV: ['Côte d’Ivoire', 'v3', '#f77f00', '#ffffff', '#009e60'],
  CMR: ['Cameroon', 'v3', '#007a5e', '#ce1126', '#fcd116'], MLI: ['Mali', 'v3', '#14b53a', '#fcd116', '#ce1126'], GUI: ['Guinea', 'v3', '#ce1126', '#fcd116', '#009460'], MAR: ['Morocco', 'star', '#c1272d', '#006233'],
  ALG: ['Algeria', 'v2', '#006633', '#ffffff'], TUN: ['Tunisia', 'circle', '#e70013', '#ffffff'], EGY: ['Egypt', 'h3', '#ce1126', '#ffffff', '#000000'], BFA: ['Burkina Faso', 'h2', '#ef2b2d', '#009e49'],
  COD: ['DR Congo', 'solid', '#007fff'], GAB: ['Gabon', 'h3', '#009e60', '#fcd116', '#3a75c4'], GAM: ['Gambia', 'h3', '#ce1126', '#0c1c8c', '#3a7728'], CPV: ['Cape Verde', 'h3', '#003893', '#ffffff', '#003893'],
  ANG: ['Angola', 'h2', '#cc092f', '#000000'], ZAM: ['Zambia', 'solid', '#198a00'], RSA: ['South Africa', 'h3', '#de3831', '#007a4d', '#002395'], BEN: ['Benin', 'v2', '#008751', '#fcd116'],
  TOG: ['Togo', 'h5', '#006a4e', '#ffce00', '#006a4e', '#ffce00', '#006a4e'], EQG: ['Equatorial Guinea', 'h3', '#3e9a00', '#ffffff', '#e32118'], CGO: ['Congo', 'v3', '#009543', '#fbde4a', '#dc241f'], ZIM: ['Zimbabwe', 'h5', '#006400', '#ffd200', '#d40000', '#ffd200', '#006400'],
  MOZ: ['Mozambique', 'h3', '#007168', '#000000', '#fce100'], COM: ['Comoros', 'h3', '#ffc61e', '#ffffff', '#3a75c4'], MAD: ['Madagascar', 'h2', '#fc3d32', '#007e3a'], SLE: ['Sierra Leone', 'h3', '#1eb53a', '#ffffff', '#0072c6'],
  KOR: ['Korea Republic', 'circle', '#ffffff', '#cd2e3a'], JPN: ['Japan', 'circle', '#ffffff', '#bc002d'], AUS: ['Australia', 'solid', '#00008b'], NZL: ['New Zealand', 'solid', '#00247d'], UZB: ['Uzbekistan', 'h3', '#0099b5', '#ffffff', '#1eb53a'],
  IRN: ['Iran', 'h3', '#239f40', '#ffffff', '#da0000'], UAE: ['United Arab Emirates', 'uae', '#00732f', '#ffffff', '#000000', '#ff0000'], KSA: ['Saudi Arabia', 'solid', '#006c35'], DOM: ['Dominican Republic', 'cross', '#002d62', '#ffffff'],
  EST: ['Estonia', 'h3', '#0072ce', '#000000', '#ffffff'], LVA: ['Latvia', 'h3', '#9e3039', '#ffffff', '#9e3039'], MDA: ['Moldova', 'v3', '#0046ae', '#ffd200', '#cc092f'], FRO: ['Faroe Islands', 'nordic', '#ffffff', '#005eb8', '#ef303e'],
  RUS: ['Russia', 'h3', '#ffffff', '#0039a6', '#d52b1e'], HON: ['Honduras', 'h3', '#0073cf', '#ffffff', '#0073cf'], CTA: ['Central African Rep.', 'h3', '#003082', '#ffffff', '#289728'], NIG: ['Niger', 'h3', '#e05206', '#ffffff', '#0db02b'],
  PAN: ['Panama', 'v2', '#005293', '#d21034'], CAF: ['Central African Rep.', 'h3', '#003082', '#ffffff', '#289728'], JOR: ['Jordan', 'h3', '#000000', '#ffffff', '#007a3d'], GNB: ['Guinea-Bissau', 'h2', '#fcd116', '#009e49'],
  GUF: ['French Guiana', 'v2', '#078930', '#fcdd09'], LBY: ['Libya', 'h3', '#e70013', '#000000', '#239e46'], IDN: ['Indonesia', 'h2', '#ce1126', '#ffffff']
};
const REAL_LEAGUES = {
  ENG1: { name: 'Premier League', short: 'EPL', nat: 'ENG', color: '#3d195b' },
  ESP1: { name: 'LaLiga', short: 'LIGA', nat: 'ESP', color: '#ff4b44' },
  ITA1: { name: 'Serie A', short: 'SA', nat: 'ITA', color: '#0a3ccb' },
  GER1: { name: 'Bundesliga', short: 'BL', nat: 'GER', color: '#d20515' },
  FRA1: { name: 'Ligue 1', short: 'L1', nat: 'FRA', color: '#0c2340' },
  LEG: { name: 'Legends', short: 'ICN', nat: null, color: '#e8d6a0', special: true }
};
/* register a club: roster = "Name;POS;NAT;OVR|..." */
function club(code, name, lg, c1, c2, roster) {
  REAL.clubs[code] = { name, lg, c: [c1, c2], roster };
  REAL.order.push(code);
}
