import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { mmkvStorage } from './storage';

/**
 * Stores last selected category so category screen can restore selection.
 */
interface CategoryStore {
  lastCategoryId: string | null;
  setLastCategoryId: (id: string | null) => void;
}

export const useCategoryStore = create<CategoryStore>()(
  persist(
    (set) => ({
      lastCategoryId: null,
      setLastCategoryId: (id) => set({ lastCategoryId: id }),
    }),
    {
      name: 'category-storage',
      storage: createJSONStorage(() => mmkvStorage),
    }
  )
);

