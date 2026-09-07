// the few remembered settings (the sign-in server, the credential-store switch), kept in
// preferences.json in the app's data folder through tauri's store plugin. from iloader's
// StoreContext.tsx; when the file cannot be opened the settings live in memory for this run
// instead of the screen staying blank.

import React, {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  useMemo,
} from "react";
import { load, Store } from "@tauri-apps/plugin-store";

type Values = { [key: string]: unknown };

export const StoreContext = createContext<{
  storeValues: Values;
  setStoreValue: (key: string, value: unknown) => void;
  storeInitialized: boolean;
}>({
  storeValues: {},
  setStoreValue: () => {},
  storeInitialized: false,
});

export const StoreProvider: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => {
  const [storeValues, setStoreValues] = useState<Values>({});
  const [store, setStore] = useState<Store | null>(null);
  const [storeInitialized, setStoreInitialized] = useState(false);

  useEffect(() => {
    const initializeStore = async () => {
      try {
        const storeInstance = await load("preferences.json");
        const keys = await storeInstance.keys();
        const values: Values = {};
        for (const key of keys) {
          values[key] = await storeInstance.get(key);
        }
        setStore(storeInstance);
        setStoreValues(values);
      } catch (e) {
        console.warn("settings file unavailable, keeping settings in memory", e);
      }
      setStoreInitialized(true);
    };

    initializeStore();
  }, []);

  const setStoreValue = useCallback(
    async (key: string, value: unknown) => {
      setStoreValues((prevValues) => ({ ...prevValues, [key]: value }));
      if (!store) return;
      try {
        await store.set(key, value);
        await store.save();
      } catch (e) {
        console.warn("could not save a setting", e);
      }
    },
    [store],
  );

  const contextValue = useMemo(
    () => ({ storeValues, setStoreValue, storeInitialized }),
    [storeValues, setStoreValue, storeInitialized],
  );

  if (!storeInitialized) {
    return null;
  }

  return (
    <StoreContext.Provider value={contextValue}>
      {children}
    </StoreContext.Provider>
  );
};

export const useStore = <T,>(
  key: string,
  initialValue: T,
): [T, (value: T | ((oldValue: T) => T)) => void, boolean] => {
  const { storeValues, setStoreValue, storeInitialized } =
    useContext(StoreContext);
  const [value, setValue] = useState<T>((storeValues[key] as T) ?? initialValue);

  useEffect(() => {
    if (storeValues[key] !== undefined && storeValues[key] !== value) {
      setValue(storeValues[key] as T);
    }
  }, [storeValues, key]);

  const setStoredValue = useCallback(
    (newValue: T | ((oldValue: T) => T)) => {
      const valueToStore =
        typeof newValue === "function"
          ? (newValue as (oldValue: T) => T)(value)
          : newValue;
      setValue(valueToStore);
      setStoreValue(key, valueToStore);
    },
    [key, setStoreValue, value],
  );

  return [value, setStoredValue, storeInitialized];
};
