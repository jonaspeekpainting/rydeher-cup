import { withTransaction } from "./db";

/**
 * Permanently deletes a user's login and profile.
 * Tournament roster names stay (organizer guest list); the invite is unclaimed
 * so the same email can sign up again if still invited.
 */
export async function deleteAccount(userId: string): Promise<boolean> {
  return withTransaction(async (tx) => {
    const existing = await tx<{ id: string }>`
      SELECT id FROM users WHERE id = ${userId} LIMIT 1
    `;
    if (!existing.rows[0]) {
      return false;
    }

    await tx`
      UPDATE invite_list
      SET claimed_at = NULL, user_id = NULL
      WHERE user_id = ${userId}
    `;

    // carrier_profile_id had no ON DELETE until migration 008.
    await tx`
      DELETE FROM pink_ball_holes WHERE carrier_profile_id = ${userId}
    `;

    await tx`
      DELETE FROM users WHERE id = ${userId}
    `;

    return true;
  });
}
