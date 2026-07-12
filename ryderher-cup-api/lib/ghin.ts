/**
 * Handicap Index provider.
 * Official GHIN access is approval-gated; when GHIN_* env is unset,
 * callers must supply a manual index.
 */

export type HandicapLookupResult = {
  handicapIndex: number;
  source: "ghin" | "manual";
  ghinNumber: string;
  raw?: unknown;
};

export function isGhinConfigured(): boolean {
  return Boolean(
    process.env.GHIN_API_BASE_URL && process.env.GHIN_API_TOKEN,
  );
}

export async function fetchHandicapIndex(
  ghinNumber: string,
  manualIndex?: number | null,
): Promise<HandicapLookupResult> {
  const cleaned = ghinNumber.replace(/\D/g, "");
  if (!cleaned) {
    throw new Error("A valid GHIN number is required");
  }

  if (isGhinConfigured()) {
    try {
      const index = await fetchFromGhin(cleaned);
      return {
        handicapIndex: index,
        source: "ghin",
        ghinNumber: cleaned,
      };
    } catch (error) {
      if (manualIndex != null && Number.isFinite(manualIndex)) {
        return {
          handicapIndex: Number(manualIndex),
          source: "manual",
          ghinNumber: cleaned,
        };
      }
      throw error;
    }
  }

  if (manualIndex == null || !Number.isFinite(manualIndex)) {
    throw new Error(
      "GHIN is not configured. Provide handicap_index manually.",
    );
  }

  return {
    handicapIndex: Number(manualIndex),
    source: "manual",
    ghinNumber: cleaned,
  };
}

async function fetchFromGhin(ghinNumber: string): Promise<number> {
  const base = process.env.GHIN_API_BASE_URL!.replace(/\/$/, "");
  const token = process.env.GHIN_API_TOKEN!;
  const url = `${base}/golfers/${ghinNumber}/handicap`;

  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    const text = await response.text().catch(() => "");
    throw new Error(
      `GHIN lookup failed (${response.status})${text ? `: ${text}` : ""}`,
    );
  }

  const data = (await response.json()) as Record<string, unknown>;
  const raw =
    data.handicap_index ??
    data.handicapIndex ??
    data.Index ??
    data.index;

  const value = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(value)) {
    throw new Error("GHIN response did not include a handicap index");
  }
  return value;
}
