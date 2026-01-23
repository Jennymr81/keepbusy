// lib/constants/app_constants.dart



// ---------- Search / interests (Search page + Profile chips) ----------
const List<String> kSearchInterestOptions = [
  'Dance',
  'Youth sports',
  'Adult sports',
  'Fitness + wellness',
  'Art',
  'Computer programs',
  'STEM',
  'Music',
  'Theater',
  'Martial arts',
  'Language',
  'Tutoring',
  'Volunteering',
  'Outdoor',
  'Cooking',
  'Esports',
  'Other',
];

// Short weekday labels used in Event Quick View / Search card subtitles
const List<String> kWeekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];



// Places toggle for the Event Entry location field
// (keep false until Google Places is fully wired)
const bool kPlacesEnabled = false;

// Valid 2-letter US state abbreviations for the Event Entry address form
const Set<String> kvalidStates = {
  'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA', 'HI', 'ID', 'IL',
  'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT',
  'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI',
  'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY', 'DC', 'PR',
};