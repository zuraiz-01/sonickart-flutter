import { create } from 'zustand';

/**
 * Lightweight shared holder for react-native-maps ref.
 * Used by live-tracking map helpers across nested components.
 */
interface MapRefStore {
    mapRef: any;
    setMapRef: (ref: any) => void
}

export const useMapRefStore = create<MapRefStore>((set) => ({
    mapRef: null,
    setMapRef: (ref) => set({ mapRef: ref }),
}));
