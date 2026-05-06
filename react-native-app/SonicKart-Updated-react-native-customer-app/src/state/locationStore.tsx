import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { mmkvStorage } from './storage';
import type { SavedAddress } from '@service/addressService';

/**
 * Location context store.
 * Holds currently selected customer address and resolved vendor id(s).
 */
interface LocationStore {
  selectedAddress: SavedAddress | null;
  selectedVendorId: string | null; // Comma-separated vendor IDs for backward compatibility
  setSelectedAddress: (address: SavedAddress | null) => void;
  setSelectedVendorId: (vendorId: string | null) => void; // Accepts comma-separated string or single ID
  clearLocationSelection: () => void;
}

export const useLocationStore = create<LocationStore>()(
  persist(
    (set) => ({
      selectedAddress: null,
      selectedVendorId: null,
      setSelectedAddress: (address) => set({ selectedAddress: address }),
      setSelectedVendorId: (vendorId) => set({ selectedVendorId: vendorId }),
      clearLocationSelection: () => set({ selectedAddress: null, selectedVendorId: null }),
    }),
    {
      name: 'location-storage',
      storage: createJSONStorage(() => mmkvStorage),
    }
  )
);
