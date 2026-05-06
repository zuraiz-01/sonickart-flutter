import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { mmkvStorage } from './storage';

/**
 * Auth store.
 * Persists user session state, current active order, and session-expired modal state.
 */
interface authStore {
  user: Record<string, any> | null;
  setUser: (user: any) => void;
  setCurrentOrder: (order: any) => void;
  currentOrder: Record<string, any> | null;
  logout: () => void;
  showSessionExpiredModal: boolean;
  setShowSessionExpiredModal: (show: boolean) => void;
}

export const useAuthStore = create<authStore>()(
  persist(
    (set) => ({
      user: null,
      currentOrder: null,
      showSessionExpiredModal: false,
      setCurrentOrder: (order) => set({ currentOrder: order }),
      setUser: (data) => set({ user: data }),
      logout: () => set({ user: null, currentOrder: null }),
      setShowSessionExpiredModal: (show) => set({ showSessionExpiredModal: show }),
    }),
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => mmkvStorage),
    }
  )
);
