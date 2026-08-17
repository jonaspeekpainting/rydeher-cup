/** Last token of a display name (e.g. "Tyler Schmalz" → "Schmalz"). */
export function lastName(full: string): string {
  const parts = full.trim().split(/\s+/).filter(Boolean);
  return parts[parts.length - 1] ?? full.trim();
}

/** First character of the first token, uppercased (e.g. "tyler" → "T"). */
export function firstInitial(full: string): string | null {
  const parts = full.trim().split(/\s+/).filter(Boolean);
  if (parts.length < 2) return null;
  const initial = parts[0]!.charAt(0);
  return initial ? initial.toUpperCase() : null;
}

/**
 * Short last-name form for compact UIs and match labels.
 * When more than one name in `among` shares the same last name, returns
 * "T. Schmalz"; otherwise just "Schmalz".
 */
export function shortLastName(
  full: string,
  among: readonly string[] = [],
): string {
  const last = lastName(full);
  if (!last) return full.trim();

  const lastKey = last.toLowerCase();
  const duplicates = among.filter(
    (name) => lastName(name).toLowerCase() === lastKey,
  );
  if (duplicates.length <= 1) {
    return last;
  }

  const initial = firstInitial(full);
  return initial ? `${initial}. ${last}` : last;
}
