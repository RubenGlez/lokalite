type DebounceOptions = {
  leading?: boolean;
};

export function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number,
  options: DebounceOptions = {}
): (...args: Parameters<T>) => void {
  let timeoutId: ReturnType<typeof setTimeout> | null = null;
  let leading = options.leading ?? false;

  return (...args: Parameters<T>): void => {
    const later = () => {
      timeoutId = null;
      if (!leading) {
        func(...args);
      }
    };

    const shouldCallNow = leading && !timeoutId;
    clearTimeout(timeoutId as ReturnType<typeof setTimeout>);
    timeoutId = setTimeout(later, wait);

    if (shouldCallNow) {
      func(...args);
    }
  };
}
