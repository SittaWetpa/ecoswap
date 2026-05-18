// Dummy data — coherent across all screens.

const PEOPLE = [
  { id: 'ploy', name: 'Ploy', location: 'Bang Mod', proximity: 'Same district', bio: 'Comm student. Decluttering my dorm.', color: '#E8B4BC' },
  { id: 'fah',  name: 'Fah',  location: 'Bang Mod', proximity: 'Same district', bio: 'Marketing. Trying to live with less.', color: '#A8C5E0' },
  { id: 'beam', name: 'Beam', location: 'Bang Mod', proximity: 'Same district', bio: 'New grad setting up my first place.', color: '#C5B8A5' },
  { id: 'mint', name: 'Mint', location: 'Bang Mod', proximity: 'Same district', bio: 'Architecture student. Books and design stuff to swap.', color: '#B8D4C0' },
  { id: 'nan',  name: 'Nan',  location: 'Bang Mod', proximity: 'Same district', bio: 'Loves cooking, has too many kitchen gadgets.', color: '#E0C2A8' },
];

// Item categories carry a CO2 intensity per kg and a typical-weight fallback
// for items where the user skipped the weight field. Methodology: per-trade
// CO2 saved = weight(received) × co2_per_kg(category). Waste = weight(given).
const CATEGORY = {
  clothing:    { label: 'Clothing',    co2_per_kg: 25,  typical_weight: 0.5 },
  books:       { label: 'Books',       co2_per_kg: 1.5, typical_weight: 0.4 },
  kitchenware: { label: 'Kitchenware', co2_per_kg: 6,   typical_weight: 1.0 },
  household:   { label: 'Household',   co2_per_kg: 4,   typical_weight: 0.5 },
  electronics: { label: 'Electronics', co2_per_kg: 80,  typical_weight: 2.0 },
  furniture:   { label: 'Furniture',   co2_per_kg: 4,   typical_weight: 8.0 },
  other:       { label: 'Other',       co2_per_kg: 5,   typical_weight: 0.5 },
};

const ITEMS = [
  { id: 'tote',     name: 'Leather tote bag',    cat: 'clothing',    cond: 'Like new', owner: 'ploy', swatch: '#8B6F4E' },
  { id: 'books3',   name: '3 design books',      cat: 'books',       cond: 'Good',     owner: 'ploy', swatch: '#C0392B' },
  { id: 'kettle',   name: 'Electric kettle',     cat: 'kitchenware', cond: 'Like new', owner: 'fah',  swatch: '#D7D5CE' },
  { id: 'lamp',     name: 'Desk lamp',           cat: 'household',   cond: 'Good',     owner: 'fah',  swatch: '#2E2E2E' },
  { id: 'mat',      name: 'Yoga mat',            cat: 'household',   cond: 'New',      owner: 'mint', swatch: '#5B8B6E' },
  { id: 'books2',   name: 'Hardcover novels (5)',cat: 'books',       cond: 'Like new', owner: 'beam', swatch: '#3B5278' },
  { id: 'cooker',   name: 'Rice cooker (1-person)', cat: 'kitchenware', cond: 'Good', owner: 'nan',  swatch: '#E8DDD0' },
  { id: 'plants',   name: 'Snake plant + pot',   cat: 'household',   cond: 'Good',     owner: 'mint', swatch: '#3F6B4E' },
  // My items
  { id: 'mine-jacket', name: 'Denim jacket',     cat: 'clothing',    cond: 'Like new', owner: 'me', swatch: '#4A6B85',
    weight: 0.6, desc: 'Bought 2 years ago, barely used. Great for daily commute.', want: 'Kitchenware or books — open to suggestions' },
  { id: 'mine-mug',    name: 'Ceramic mug set',  cat: 'kitchenware', cond: 'Good',     owner: 'me', swatch: '#A8856B',
    weight: 0.8, desc: 'Set of 4. One has a small chip on the rim, others perfect.', want: 'A reading lamp or small plant' },
  { id: 'mine-lamp',   name: 'Reading lamp',     cat: 'household',   cond: 'Like new', owner: 'me', swatch: '#D4B996',
    weight: 1.2, desc: 'Warm LED, dimmable. Bought new last semester.', want: 'Textbooks or kitchenware' },
  { id: 'mine-books',  name: 'Used textbooks (4)', cat: 'books',     cond: 'Good',     owner: 'me', swatch: '#5B7556',
    weight: 2.4, desc: 'Intro CS, calc 1, linear algebra, stats. Some highlighting.', want: 'Anything useful — surprise me' },
];

const itemsBy = (ownerId) => ITEMS.filter(i => i.owner === ownerId);
const itemById = (id) => ITEMS.find(i => i.id === id);
const personById = (id) => PEOPLE.find(p => p.id === id);

// Trade history — feeds Impact dashboard. ↔ pairs.
const TRADES = [
  { date: 'May 12', mine: 'mine-jacket', theirs: 'tote',   with: 'ploy' },
  { date: 'May 03', mine: 'mine-books',  theirs: 'lamp',   with: 'fah'  },
  { date: 'Apr 26', mine: 'mine-mug',    theirs: 'kettle', with: 'fah'  },
  { date: 'Apr 14', mine: 'mine-lamp',   theirs: 'books2', when: 'evening', with: 'beam' },
  { date: 'Apr 02', mine: 'mine-books',  theirs: 'cooker', with: 'nan'  },
  { date: 'Mar 21', mine: 'mine-jacket', theirs: 'mat',    with: 'mint' },
  { date: 'Mar 08', mine: 'mine-mug',    theirs: 'plants', with: 'mint' },
];

// Pre-totaled (matches the 47.5kg / 12.3kg targets in style guide)
const IMPACT = {
  itemsSwapped: 7,
  co2: 47.5,
  waste: 12.3,
  goalCo2: 60,
  avgUserCo2: 18.4,
};

const CHAT_MESSAGES = [
  { who: 'them', text: 'Hi! Saw your tote bag — would you swap for my electric kettle?', time: '14:02' },
  { who: 'me',   text: 'Yes! When can we meet?', time: '14:04' },
  { who: 'them', text: 'How about tomorrow 6pm at Asoke BTS exit 2?', time: '14:05' },
  { who: 'me',   text: 'Perfect, see you there 🙌', time: '14:06' },
];

Object.assign(window, { PEOPLE, ITEMS, CATEGORY, TRADES, IMPACT, CHAT_MESSAGES, itemsBy, itemById, personById });
