import { create } from 'zustand';
import {
  DEFAULT_DELIVERY_SETTINGS,
  fetchDeliverySettings,
  getDeliverySettingsSnapshot,
  setDeliverySettingsSnapshot,
  type DeliverySettings,
} from '@service/deliverySettingsService';

type LoadSettingsOptions = {
  force?: boolean;
};

type DeliverySettingsState = {
  settings: DeliverySettings;
  loading: boolean;
  loaded: boolean;
  error: string | null;
  applySettings: (settings: DeliverySettings) => void;
  loadSettings: (options?: LoadSettingsOptions) => Promise<DeliverySettings>;
};

export const useDeliverySettingsStore = create<DeliverySettingsState>(
  (set, get) => ({
    settings: { ...DEFAULT_DELIVERY_SETTINGS },
    loading: false,
    loaded: false,
    error: null,
    applySettings: (settings) => {
      setDeliverySettingsSnapshot(settings);
      set({
        settings: getDeliverySettingsSnapshot(),
        loaded: true,
        error: null,
      });
    },
    loadSettings: async (options) => {
      const currentState = get();

      if (currentState.loading) {
        return currentState.settings;
      }

      if (currentState.loaded && !options?.force) {
        return currentState.settings;
      }

      set({ loading: true, error: null });

      try {
        const settings = await fetchDeliverySettings(options);
        set({
          settings,
          loading: false,
          loaded: true,
          error: null,
        });
        return settings;
      } catch (error) {
        const message =
          error instanceof Error
            ? error.message
            : 'Failed to load delivery settings.';

        setDeliverySettingsSnapshot(currentState.settings);
        set({
          settings: getDeliverySettingsSnapshot(),
          loading: false,
          loaded: true,
          error: message,
        });
        return get().settings;
      }
    },
  })
);
