// src/services/premium.service.ts
import { prisma } from "../utils/db";

/**
 * 🔒 PREMIUM SERVICE
 * Manages user premium/subscription status
 * 
 * For production, integrate with:
 * - RevenueCat
 * - Stripe
 * - Google Play Billing
 * - Apple App Store
 */
export class PremiumService {
  /**
   * Check if user has active premium subscription
   * 
   * @param userId - User ID to check
   * @returns true if user has premium access, false otherwise
   */
  async isPremium(userId: string): Promise<boolean> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { isPremium: true }
    });
    
    // Default to FALSE - users must pay to access AI features
    return user?.isPremium ?? false;
  }

  /**
   * Grant premium access to user (call after successful payment)
   * 
   * @param userId - User ID to grant premium
   */
  async setPremium(userId: string, isPremium: boolean = true): Promise<void> {
    await prisma.user.update({
      where: { id: userId },
      data: { 
        isPremium,
        updatedAt: new Date()
      }
    });

    // Log event for analytics
    await prisma.event.create({
      data: {
        userId,
        type: 'user_profile_update',
        payload: { 
          action: isPremium ? 'premium_granted' : 'premium_revoked',
          timestamp: new Date().toISOString()
        }
      }
    });
  }

  /**
   * Check if user should receive AI-powered features
   * This includes:
   * - Daily briefs/debriefs
   * - AI chat
   * - What-If engine
   * - Nudges
   */
  async canAccessAI(userId: string): Promise<boolean> {
    return this.isPremium(userId);
  }
}

export const premiumService = new PremiumService();

