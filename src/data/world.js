/* ============================================================
   DATA / WORLD — nations, fictional leagues & clubs
   All club and league names are original/fictional.
   ============================================================ */
const NATIONS = {
  ENG: { name: 'England', flag: { t: 'cross', c: ['#ffffff', '#cf142b'] }, first: ['Harry', 'Jack', 'Oliver', 'Callum', 'Mason', 'Reece', 'Tom', 'Ben', 'Jordan', 'Luke', 'Alfie', 'Charlie'], last: ['Whitmore', 'Ashdown', 'Fletcher', 'Hollis', 'Bramwell', 'Cartwright', 'Pembroke', 'Langley', 'Thornton', 'Hadley', 'Kingsley', 'Rowntree'] },
  ESP: { name: 'Spain', flag: { t: 'h3', c: ['#aa151b', '#f1bf00', '#aa151b'], w: [1, 2, 1] }, first: ['Pablo', 'Álvaro', 'Iker', 'Sergio', 'Dani', 'Marcos', 'Rubén', 'Hugo', 'Adrián', 'Javi', 'Nico', 'Raúl'], last: ['Montoya', 'Salvatierra', 'Quintero', 'Barrera', 'Escudero', 'Navarro', 'Peñalver', 'Robledo', 'Cuadrado', 'Lozano', 'Valdés', 'Arrieta'] },
  FRA: { name: 'France', flag: { t: 'v3', c: ['#0055a4', '#ffffff', '#ef4135'] }, first: ['Théo', 'Lucas', 'Antoine', 'Mathis', 'Hugo', 'Clément', 'Rayan', 'Enzo', 'Bastien', 'Yanis', 'Jules', 'Maxime'], last: ['Delacroix', 'Moreau', 'Lefèvre', 'Garnier', 'Bonnard', 'Fontaine', 'Rousseau', 'Chevalier', 'Mercier', 'Dufresne', 'Laurent', 'Perrin'] },
  GER: { name: 'Germany', flag: { t: 'h3', c: ['#000000', '#dd0000', '#ffce00'] }, first: ['Lukas', 'Jonas', 'Felix', 'Leon', 'Niklas', 'Tim', 'Florian', 'Kai', 'Julian', 'Moritz', 'Jan', 'Paul'], last: ['Brandt', 'Hoffmann', 'Kessler', 'Vogel', 'Steinbach', 'Krüger', 'Lindner', 'Hartmann', 'Weber', 'Adler', 'Neumann', 'Falk'] },
  ITA: { name: 'Italy', flag: { t: 'v3', c: ['#009246', '#ffffff', '#ce2b37'] }, first: ['Marco', 'Lorenzo', 'Federico', 'Matteo', 'Giacomo', 'Davide', 'Riccardo', 'Alessio', 'Nicolò', 'Simone', 'Andrea', 'Pietro'], last: ['Ferraro', 'Bellandi', 'Carbone', 'Montalto', 'Ricci', 'Lombardi', 'Santoro', 'Galli', 'Vitale', 'Romagnoli', 'DeLuca', 'Fabbri'] },
  POR: { name: 'Portugal', flag: { t: 'v2', c: ['#006600', '#ff0000'], w: [2, 3] }, first: ['João', 'Diogo', 'Rafael', 'Tiago', 'Gonçalo', 'Rúben', 'Bruno', 'Pedro', 'Vitinha', 'Nuno', 'André', 'Fábio'], last: ['Carvalho', 'Pereira', 'Monteiro', 'Teixeira', 'Figueira', 'Sardinha', 'Barroso', 'Couto', 'Mendonça', 'Rebelo', 'Amaral', 'Pinto'] },
  NED: { name: 'Netherlands', flag: { t: 'h3', c: ['#ae1c28', '#ffffff', '#21468b'] }, first: ['Daan', 'Sem', 'Tijn', 'Joris', 'Bram', 'Stijn', 'Ruben', 'Milan', 'Jesse', 'Lars', 'Thijs', 'Noah'], last: ['van Dijkhuis', 'de Groot', 'Bakker', 'Visser', 'Smit', 'Mulder', 'de Wit', 'Kuipers', 'Vermeer', 'Hendriks', 'Jansen', 'van Leeuwen'] },
  BRA: { name: 'Brazil', flag: { t: 'diamond', c: ['#009c3b', '#ffdf00', '#002776'] }, first: ['Gabriel', 'Lucas', 'Matheus', 'Rodrigo', 'Thiago', 'Vitor', 'Felipe', 'Caio', 'Davi', 'Igor', 'Renan', 'Wesley'], last: ['Silvano', 'Andrade', 'Barbosa', 'Cardoso', 'Nogueira', 'Moraes', 'Siqueira', 'Rocha', 'Batista', 'Freitas', 'Lima', 'Vasconcelos'] },
  ARG: { name: 'Argentina', flag: { t: 'h3', c: ['#74acdf', '#ffffff', '#74acdf'] }, first: ['Lautaro', 'Julián', 'Tomás', 'Bautista', 'Valentín', 'Nahuel', 'Facundo', 'Gonzalo', 'Franco', 'Santiago', 'Ezequiel', 'Leandro'], last: ['Ferreyra', 'Acosta', 'Correa', 'Gaitán', 'Benítez', 'Sosa', 'Medina', 'Villalba', 'Aguirre', 'Ledesma', 'Quiroga', 'Ojeda'] },
  BEL: { name: 'Belgium', flag: { t: 'v3', c: ['#000000', '#fdda24', '#ef3340'] }, first: ['Arthur', 'Louis', 'Jérémy', 'Maxim', 'Wout', 'Arne', 'Senne', 'Loïs', 'Charles', 'Yari', 'Hans', 'Dries'], last: ['Peeters', 'Claes', 'Wouters', 'Maes', 'Lambert', 'Dumont', 'Vandamme', 'Goossens', 'Declercq', 'Willems', 'Martens', 'Michiels'] },
  CRO: { name: 'Croatia', flag: { t: 'h3', c: ['#ff0000', '#ffffff', '#171796'] }, first: ['Filip', 'Ivan', 'Marko', 'Josip', 'Mateo', 'Ante', 'Nikola', 'Dominik', 'Toni', 'Petar', 'Borna', 'Lovro'], last: ['Horvat', 'Babić', 'Marić', 'Jurić', 'Knežević', 'Vuković', 'Perić', 'Pavlović', 'Šimić', 'Radić', 'Tomić', 'Novak'] },
  URU: { name: 'Uruguay', flag: { t: 'h5', c: ['#ffffff', '#0038a8', '#ffffff', '#0038a8', '#ffffff'] }, first: ['Federico', 'Rodrigo', 'Bruno', 'Manuel', 'Agustín', 'Facundo', 'Nicolás', 'Maxi', 'Matías', 'Gastón', 'Sebastián', 'Brian'], last: ['Olivera', 'Castro', 'Pereyra', 'Rodríguez', 'Silveira', 'Larrosa', 'Cabrera', 'Ferrando', 'Techera', 'Morales', 'Acuña', 'Gómez'] },
  NGA: { name: 'Nigeria', flag: { t: 'v3', c: ['#008751', '#ffffff', '#008751'] }, first: ['Victor', 'Samuel', 'Chinedu', 'Ifeanyi', 'Kelechi', 'Ademola', 'Uche', 'Segun', 'Taiwo', 'Chidera', 'Emeka', 'Tolu'], last: ['Okafor', 'Adeyemi', 'Nwosu', 'Eze', 'Balogun', 'Okonkwo', 'Afolabi', 'Obi', 'Ajayi', 'Uzor', 'Chukwu', 'Adebayo'] },
  SEN: { name: 'Senegal', flag: { t: 'v3', c: ['#00853f', '#fdef42', '#e31b23'] }, first: ['Mamadou', 'Ousmane', 'Pape', 'Ibrahima', 'Aliou', 'Cheikh', 'Moussa', 'Abdou', 'Malick', 'Habib', 'Babacar', 'Assane'], last: ['Diallo', 'Ndiaye', 'Sarr', 'Gueye', 'Diouf', 'Cissé', 'Sow', 'Thiam', 'Faye', 'Ba', 'Fall', 'Seck'] },
  JPN: { name: 'Japan', flag: { t: 'circle', c: ['#ffffff', '#bc002d'] }, first: ['Takumi', 'Kaoru', 'Daichi', 'Ritsu', 'Wataru', 'Haruto', 'Hiroki', 'Sota', 'Junya', 'Ren', 'Kenta', 'Yuto'], last: ['Tanaka', 'Yamada', 'Saito', 'Kobayashi', 'Hayashi', 'Morita', 'Nakamura', 'Fujita', 'Ogawa', 'Sasaki', 'Matsuda', 'Inoue'] },
  USA: { name: 'United States', flag: { t: 'h5', c: ['#b22234', '#ffffff', '#b22234', '#ffffff', '#3c3b6e'], w: [1, 1, 1, 1, 1] }, first: ['Cole', 'Brandon', 'Tyler', 'Mason', 'Logan', 'Ryan', 'Josh', 'Caleb', 'Dylan', 'Austin', 'Wyatt', 'Matt'], last: ['Bennett', 'Hughes', 'Coleman', 'Parker', 'Sullivan', 'Brooks', 'Hayes', 'Foster', 'Griffin', 'Wallace', 'Harper', 'Morris'] },
  MAR: { name: 'Morocco', flag: { t: 'solidstar', c: ['#c1272d', '#006233'] }, first: ['Anas', 'Yassine', 'Soufiane', 'Youssef', 'Hamza', 'Nabil', 'Bilal', 'Karim', 'Amine', 'Ilias', 'Mehdi', 'Zakaria'], last: ['Benali', 'Tazi', 'Alaoui', 'Bennani', 'Idrissi', 'Chraibi', 'Fassi', 'Berrada', 'Lahlou', 'Kettani', 'Sebti', 'Amrani'] },
  NOR: { name: 'Norway', flag: { t: 'nordic', c: ['#ba0c2f', '#ffffff', '#00205b'] }, first: ['Even', 'Martin', 'Sander', 'Alexander', 'Kristoffer', 'Jørgen', 'Fredrik', 'Oscar', 'Leo', 'Henrik', 'Sindre', 'Mats'], last: ['Aasen', 'Lunde', 'Brekke', 'Solheim', 'Fjeld', 'Strand', 'Larsen', 'Haugen', 'Nygaard', 'Bakken', 'Berg', 'Moen'] },
  COL: { name: 'Colombia', flag: { t: 'h3', c: ['#fcd116', '#003893', '#ce1126'], w: [2, 1, 1] }, first: ['Luis', 'Andrés', 'Jhon', 'Camilo', 'Richard', 'Jefferson', 'Sebastián', 'Daniel', 'Rafael', 'Mateus', 'Kevin', 'Juan'], last: ['Ospina', 'Zapata', 'Restrepo', 'Valencia', 'Ríos', 'Montoya', 'Mosquera', 'Muñoz', 'Henao', 'Uribe', 'Castaño', 'Cuesta'] },
  UAE: { name: 'United Arab Emirates', flag: { t: 'uae', c: ['#00732f', '#ffffff', '#000000', '#ff0000'] }, first: ['Ali', 'Khalifa', 'Harib', 'Yahya', 'Abdullah', 'Rashid', 'Sultan', 'Omar', 'Majed', 'Saeed', 'Khalid', 'Hamad'], last: ['AlKetbi', 'AlShamsi', 'AlNeyadi', 'AlDhaheri', 'AlMansoori', 'AlKaabi', 'AlMenhali', 'AlSuwaidi', 'AlBlooshi', 'AlZaabi', 'AlMazrouei', 'AlHosani'] }
};

const LEAGUES = {
  PCL: { name: 'Premier Crown League', short: 'PCL', nat: 'ENG', strength: 6, color: '#7a2ff5' },
  LSO: { name: 'Liga Sol', short: 'SOL', nat: 'ESP', strength: 5, color: '#ff6a2b' },
  SAU: { name: 'Serie Aurea', short: 'AUR', nat: 'ITA', strength: 4, color: '#1f7bff' },
  BKL: { name: 'Bundesklasse', short: 'BKL', nat: 'GER', strength: 4, color: '#e21b2c' },
  LLU: { name: 'Ligue Lumière', short: 'LUM', nat: 'FRA', strength: 3, color: '#13c9a8' },
  APL: { name: 'Atlantic Pro League', short: 'ATL', nat: 'POR', alt: 'NED', strength: 2, color: '#19b34b' },
  LEG: { name: 'Legends', short: 'ICN', nat: null, strength: 0, color: '#e8d6a0', special: true }
};

const CLUBS = {
  // Premier Crown League
  KBU: { name: 'Kingsbridge United', lg: 'PCL', c: ['#c8102e', '#ffffff'], str: 83 },
  NGC: { name: 'Northgate City', lg: 'PCL', c: ['#6cabdd', '#1c2c5b'], str: 85 },
  RVA: { name: 'Ravenmoor Athletic', lg: 'PCL', c: ['#111111', '#d4af37'], str: 78 },
  TVR: { name: 'Thamesview Rovers', lg: 'PCL', c: ['#034694', '#ffffff'], str: 80 },
  IVF: { name: 'Ironvale FC', lg: 'PCL', c: ['#7a263a', '#1bb1e7'], str: 75 },
  WBW: { name: 'Westbury Wanderers', lg: 'PCL', c: ['#fdb913', '#231f20'], str: 73 },
  HMT: { name: 'Hollowmere Town', lg: 'PCL', c: ['#ffffff', '#132257'], str: 79 },
  CFA: { name: 'Castleford Albion', lg: 'PCL', c: ['#0057b8', '#ffcd00'], str: 70 },
  // Liga Sol
  RAU: { name: 'Real Aurora', lg: 'LSO', c: ['#ffffff', '#febe10'], str: 86 },
  AVD: { name: 'Atlético Valdoro', lg: 'LSO', c: ['#cb3524', '#272e61'], str: 80 },
  CDM: { name: 'CD Marisol', lg: 'LSO', c: ['#004d98', '#a50044'], str: 84 },
  DSI: { name: 'Deportivo Sierra', lg: 'LSO', c: ['#0067b1', '#ffffff'], str: 72 },
  RCO: { name: 'Racing Costa', lg: 'LSO', c: ['#00954c', '#ffffff'], str: 74 },
  UDM: { name: 'UD Montaña', lg: 'LSO', c: ['#ffe667', '#005999'], str: 76 },
  CFB: { name: 'CF Bravía', lg: 'LSO', c: ['#e30613', '#ffffff'], str: 69 },
  CLB: { name: 'Ciudad Lumbre', lg: 'LSO', c: ['#f48120', '#0a0a0a'], str: 71 },
  // Serie Aurea
  ACV: { name: 'AC Vesuvio', lg: 'SAU', c: ['#12a0d7', '#ffffff'], str: 81 },
  ILG: { name: 'Inter Laguna', lg: 'SAU', c: ['#010e80', '#000000'], str: 83 },
  STO: { name: 'Sporting Torre', lg: 'SAU', c: ['#ffffff', '#000000'], str: 80 },
  ASC: { name: 'AS Corvo', lg: 'SAU', c: ['#8e1f2f', '#f0bc42'], str: 77 },
  VMA: { name: 'Virtus Marea', lg: 'SAU', c: ['#87d8f7', '#ffffff'], str: 75 },
  OSE: { name: 'Olimpia Serra', lg: 'SAU', c: ['#482e92', '#ffffff'], str: 74 },
  USP: { name: 'US Pietra', lg: 'SAU', c: ['#1e71b8', '#000000'], str: 76 },
  CLI: { name: 'Calcio Lirico', lg: 'SAU', c: ['#fb090b', '#000000'], str: 69 },
  // Bundesklasse
  FCA: { name: 'FC Adlerberg', lg: 'BKL', c: ['#dc052d', '#0066b2'], str: 85 },
  SVR: { name: 'SV Rheinstahl', lg: 'BKL', c: ['#fde100', '#000000'], str: 80 },
  ENW: { name: 'Eintracht Nordwald', lg: 'BKL', c: ['#e1000f', '#000000'], str: 76 },
  FKF: { name: '1. FC Kaiserfeld', lg: 'BKL', c: ['#e32221', '#ffffff'], str: 74 },
  TBT: { name: 'TSV Bergtal', lg: 'BKL', c: ['#1c63b7', '#ffffff'], str: 72 },
  UHS: { name: 'Union Hafenstadt', lg: 'BKL', c: ['#eb1923', '#ffd700'], str: 75 },
  FEL: { name: 'Fortuna Elbstein', lg: 'BKL', c: ['#e2001a', '#ffffff'], str: 68 },
  SLH: { name: 'SC Löwenhof', lg: 'BKL', c: ['#005ca9', '#ffffff'], str: 79 },
  // Ligue Lumière
  OAZ: { name: 'Olympique Azur', lg: 'LLU', c: ['#2faee0', '#ffffff'], str: 79 },
  EPA: { name: 'Étoile Parisienne', lg: 'LLU', c: ['#004170', '#da291c'], str: 85 },
  SAR: { name: 'Stade Ardent', lg: 'LLU', c: ['#e2001a', '#000000'], str: 74 },
  ASB: { name: 'AS Bellerive', lg: 'LLU', c: ['#da291c', '#ffffff'], str: 76 },
  FMC: { name: 'FC Montclair', lg: 'LLU', c: ['#ffffff', '#1c3f94'], str: 72 },
  RLU: { name: 'Racing Lune', lg: 'LLU', c: ['#ffd800', '#000000'], str: 70 },
  RVB: { name: 'RC Vauban', lg: 'LLU', c: ['#00a650', '#ffffff'], str: 71 },
  EAB: { name: 'En Avant Brume', lg: 'LLU', c: ['#4a2e7c', '#ffffff'], str: 67 },
  // Atlantic Pro League
  SAT: { name: 'Sporting Atlântico', lg: 'APL', c: ['#008057', '#ffffff'], str: 78 },
  SLN: { name: 'SL Navegantes', lg: 'APL', c: ['#e83030', '#ffffff'], str: 79 },
  FCF: { name: 'FC Farol', lg: 'APL', c: ['#003893', '#ffffff'], str: 77 },
  VKA: { name: 'Vitesse Kanaal', lg: 'APL', c: ['#d2122e', '#ffffff'], str: 76 },
  FMW: { name: 'FC Molenwijk', lg: 'APL', c: ['#ed1c24', '#000000'], str: 73 },
  HVU: { name: 'Haven United', lg: 'APL', c: ['#ff7f00', '#000000'], str: 70 },
  DKS: { name: 'Dijkstad SC', lg: 'APL', c: ['#e30613', '#ffffff'], str: 68 },
  CDF: { name: 'CD Farilhões', lg: 'APL', c: ['#000000', '#ffffff'], str: 66 },
  // special
  ICN: { name: 'Icons', lg: 'LEG', c: ['#e8d6a0', '#2b2416'], str: 0, special: true },
  HER: { name: 'Heroes', lg: null, c: ['#6b2ea6', '#ffd23f'], str: 0, special: true }
};

const POSITIONS = ['GK', 'CB', 'LB', 'RB', 'LWB', 'RWB', 'CDM', 'CM', 'CAM', 'LM', 'RM', 'LW', 'RW', 'CF', 'ST'];
const ALT_POS = {
  GK: [], CB: ['CDM'], LB: ['LWB', 'LM'], RB: ['RWB', 'RM'], LWB: ['LB', 'LM'], RWB: ['RB', 'RM'],
  CDM: ['CM', 'CB'], CM: ['CDM', 'CAM'], CAM: ['CM', 'CF'], LM: ['LW', 'LB'], RM: ['RW', 'RB'],
  LW: ['LM', 'ST'], RW: ['RM', 'ST'], CF: ['ST', 'CAM'], ST: ['CF']
};
const POS_GROUP = { GK: 'GK', CB: 'DEF', LB: 'DEF', RB: 'DEF', LWB: 'DEF', RWB: 'DEF', CDM: 'MID', CM: 'MID', CAM: 'MID', LM: 'MID', RM: 'MID', LW: 'ATT', RW: 'ATT', CF: 'ATT', ST: 'ATT' };

/* ---------- flag rendering (SVG, original vector simplifications) ---------- */
function flagSVG(code, w = 24, h = 16) {
  const n = NATIONS[code]; if (!n) return '';
  const f = n.flag, c = f.c;
  let inner = '';
  const W = 30, H = 20;
  if (f.t === 'v3' || f.t === 'v2') {
    const ws = f.w || c.map(() => 1), tot = ws.reduce((a, b) => a + b, 0); let x = 0;
    c.forEach((col, i) => { const ww = W * ws[i] / tot; inner += `<rect x="${x}" y="0" width="${ww + 0.2}" height="${H}" fill="${col}"/>`; x += ww; });
  } else if (f.t === 'h3' || f.t === 'h5') {
    const ws = f.w || c.map(() => 1), tot = ws.reduce((a, b) => a + b, 0); let y = 0;
    c.forEach((col, i) => { const hh = H * ws[i] / tot; inner += `<rect x="0" y="${y}" width="${W}" height="${hh + 0.2}" fill="${col}"/>`; y += hh; });
    if (code === 'USA') inner += `<rect x="0" y="0" width="13" height="10" fill="#3c3b6e"/>`;
    if (code === 'URU') inner += `<rect x="0" y="0" width="11" height="10" fill="#fff"/><circle cx="5.5" cy="5" r="3" fill="#fcd116"/>`;
    if (code === 'ARG') inner += `<circle cx="15" cy="10" r="2.2" fill="#f6b40e"/>`;
    if (code === 'CRO') inner += `<rect x="12" y="5" width="6" height="7" fill="#fff" stroke="#ff0000" stroke-width="0.6"/>`;
  } else if (f.t === 'cross') {
    inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/><rect x="13" y="0" width="4" height="${H}" fill="${c[1]}"/><rect x="0" y="8" width="${W}" height="4" fill="${c[1]}"/>`;
  } else if (f.t === 'nordic') {
    inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/><rect x="8" y="0" width="6" height="${H}" fill="${c[1]}"/><rect x="0" y="7" width="${W}" height="6" fill="${c[1]}"/><rect x="9.5" y="0" width="3" height="${H}" fill="${c[2]}"/><rect x="0" y="8.5" width="${W}" height="3" fill="${c[2]}"/>`;
  } else if (f.t === 'diamond') {
    inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/><polygon points="15,2 28,10 15,18 2,10" fill="${c[1]}"/><circle cx="15" cy="10" r="4.5" fill="${c[2]}"/>`;
  } else if (f.t === 'circle') {
    inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/><circle cx="15" cy="10" r="6" fill="${c[1]}"/>`;
  } else if (f.t === 'solidstar') {
    inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/><polygon points="15,4 16.8,9.2 22,9.2 17.8,12.4 19.4,17.5 15,14.3 10.6,17.5 12.2,12.4 8,9.2 13.2,9.2" fill="none" stroke="${c[1]}" stroke-width="1.2"/>`;
  } else if (f.t === 'uae') {
    inner = `<rect width="${W}" height="${H}" fill="${c[1]}"/><rect width="${W}" height="6.67" fill="${c[0]}"/><rect y="13.33" width="${W}" height="6.67" fill="${c[2]}"/><rect width="8" height="${H}" fill="${c[3]}"/>`;
  }
  return `<svg class="flag" viewBox="0 0 ${W} ${H}" width="${w}" height="${h}" preserveAspectRatio="none">${inner}</svg>`;
}

/* ---------- club crest (original procedural badges) ---------- */
function crestSVG(clubCode, size = 22) {
  const cl = CLUBS[clubCode]; if (!cl) return '';
  const [a, b] = cl.c;
  const hsh = hashStr(clubCode);
  const style = hsh % 4;
  const init = cl.name.split(' ').filter(w => w.length > 2 && !['FC', 'CD', 'AC', 'AS', 'SV', 'US', 'UD', 'CF', 'SC', 'SL', 'RC', 'TSV'].includes(w))[0]?.[0] || cl.name[0];
  if (clubCode === 'ICN') return `<svg viewBox="0 0 40 40" width="${size}" height="${size}"><circle cx="20" cy="20" r="18" fill="#2b2416" stroke="#e8d6a0" stroke-width="2.5"/><text x="20" y="25.5" text-anchor="middle" font-size="14" font-weight="900" fill="#e8d6a0" font-family="Arial Black,Arial">I</text></svg>`;
  if (clubCode === 'HER') return `<svg viewBox="0 0 40 40" width="${size}" height="${size}"><polygon points="20,2 37,12 37,28 20,38 3,28 3,12" fill="#3a1666" stroke="#ffd23f" stroke-width="2.5"/><text x="20" y="25.5" text-anchor="middle" font-size="14" font-weight="900" fill="#ffd23f" font-family="Arial Black,Arial">H</text></svg>`;
  let shape;
  if (style === 0) shape = `<path d="M20 2 L36 7 L36 20 C36 30 28 36 20 38 C12 36 4 30 4 20 L4 7 Z" fill="${a}" stroke="${b}" stroke-width="2.5"/><path d="M20 2 L20 38" stroke="${b}" stroke-width="5" opacity=".55"/>`;
  else if (style === 1) shape = `<circle cx="20" cy="20" r="17" fill="${a}" stroke="${b}" stroke-width="3"/><circle cx="20" cy="20" r="11" fill="none" stroke="${b}" stroke-width="1.5" opacity=".6"/>`;
  else if (style === 2) shape = `<path d="M6 4 H34 V22 C34 31 27 36 20 38 C13 36 6 31 6 22 Z" fill="${b}" stroke="${a}" stroke-width="2.5"/><path d="M6 4 H34 V14 H6 Z" fill="${a}"/>`;
  else shape = `<polygon points="20,2 36,10 36,30 20,38 4,30 4,10" fill="${a}" stroke="${b}" stroke-width="2.5"/><polygon points="20,8 30,13 30,27 20,32 10,27 10,13" fill="none" stroke="${b}" stroke-width="1.2" opacity=".7"/>`;
  const txt = style === 2 ? a : b;
  return `<svg viewBox="0 0 40 40" width="${size}" height="${size}">${shape}<text x="20" y="${style === 2 ? 30 : 26}" text-anchor="middle" font-size="13" font-weight="900" fill="${txt}" font-family="Arial Black,Arial" stroke="${style === 2 ? b : a}" stroke-width=".4">${esc(init)}</text></svg>`;
}

function leagueSVG(lg, size = 20) {
  const L = LEAGUES[lg]; if (!L) return '';
  return `<svg viewBox="0 0 40 40" width="${size}" height="${size}"><rect x="3" y="3" width="34" height="34" rx="9" fill="${L.color}"/><text x="20" y="25" text-anchor="middle" font-size="11" font-weight="900" fill="#fff" font-family="Arial Black,Arial">${L.short}</text></svg>`;
}
