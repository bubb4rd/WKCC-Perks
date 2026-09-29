/**
 * Business / deal categories. These are Chambermate's business category labels
 * verbatim (plus "Other" as the fallback), so synced businesses need no
 * mapping. Must stay in sync with `DealCategory` in the iOS app.
 */
export const CATEGORIES = [
  "Advertising & Media",
  "Arts, Culture & Entertainment",
  "Automotive & Marine",
  "Business & Professional Services",
  "Computers & Telecommunications",
  "Construction Equipment & Contractors",
  "Family, Community & Civic Organizations",
  "Finance & Insurance",
  "Government, Education & Individuals",
  "Health Care",
  "Health Care & Wellness",
  "Home & Garden",
  "Industrial Supplies & Services",
  "Legal",
  "Lodging & Travel",
  "Personal Services & Care",
  "Pets & Veterinary",
  "Real Estate, Moving & Storage",
  "Religious Organizations",
  "Restaurants, Food & Beverages",
  "Shopping & Specialty Retail",
  "Sports & Recreation",
  "Transportation",
  "Other",
] as const;

const ALLOWED = new Set<string>(CATEGORIES);

/**
 * The app's original category names, which older app builds still send.
 * Stored data was renamed by 20260929230000_chamber_members_category_source.sql.
 */
const LEGACY_ALIASES: Record<string, string> = {
  "Shopping and Specialty Retail": "Shopping & Specialty Retail",
  "Home and Garden": "Home & Garden",
  "Restaurants, Food and Beverages": "Restaurants, Food & Beverages",
  "Government, Education and Individuals": "Government, Education & Individuals",
  "Personal Services and Care": "Personal Services & Care",
  "Business and Professional Services": "Business & Professional Services",
  "Finance and Insurance": "Finance & Insurance",
  "Advertising and Media": "Advertising & Media",
};

/** Returns the canonical category for `value`, or null if it isn't one. */
export function normalizeCategory(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  const canonical = LEGACY_ALIASES[trimmed] ?? trimmed;
  return ALLOWED.has(canonical) ? canonical : null;
}
