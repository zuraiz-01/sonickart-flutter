import { tokenStorage } from '@state/storage';
import { refresh_tokens } from './authService';
import { jwtDecode } from 'jwt-decode';

/**
 * Background token lifecycle manager.
 * Proactively refreshes access token before expiry and on app resume.
 */
interface DecodedToken {
  exp: number;
  userId: string;
  role: string;
}

class TokenManager {
  private refreshTimer: NodeJS.Timeout | null = null;
  private isRefreshing = false;

  // Check if token is about to expire (within 1 hour)
  private isTokenExpiringSoon(token: string): boolean {
    try {
      const decoded: DecodedToken = jwtDecode(token);
      const currentTime = Date.now() / 1000;
      const timeUntilExpiry = decoded.exp - currentTime;

      // Refresh if token expires within 1 hour (3600 seconds)
      return timeUntilExpiry < 3600;
    } catch (error) {
      console.log('Error decoding token:', error);
      return true; // If we can't decode, assume it needs refresh
    }
  }

  // Proactively refresh token if needed
  public async checkAndRefreshToken(): Promise<void> {
    if (this.isRefreshing) {return;}

    const accessToken = tokenStorage.getString('accessToken');
    if (!accessToken) {return;}

    if (this.isTokenExpiringSoon(accessToken)) {
      this.isRefreshing = true;
      try {
        await refresh_tokens();
        console.log('Token refreshed proactively');
      } catch (error) {
        console.log('Proactive token refresh failed:', error);
      } finally {
        this.isRefreshing = false;
      }
    }
  }

  // Start automatic token checking
  public startTokenMonitoring(): void {
    this.stopTokenMonitoring(); // Clear any existing timer

    // Check every 30 minutes
    this.refreshTimer = setInterval(() => {
      this.checkAndRefreshToken();
    }, 30 * 60 * 1000);

    // Also check immediately
    this.checkAndRefreshToken();
  }

  // Stop automatic token checking
  public stopTokenMonitoring(): void {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = null;
    }
  }

  // Get time until token expires (in minutes)
  public getTokenExpiryTime(): number | null {
    const accessToken = tokenStorage.getString('accessToken');
    if (!accessToken) {return null;}

    try {
      const decoded: DecodedToken = jwtDecode(accessToken);
      const currentTime = Date.now() / 1000;
      const timeUntilExpiry = decoded.exp - currentTime;

      return Math.floor(timeUntilExpiry / 60); // Return minutes
    } catch (error) {
      return null;
    }
  }
}

export const tokenManager = new TokenManager();
