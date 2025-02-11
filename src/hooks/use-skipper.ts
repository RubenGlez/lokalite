import { useCallback, useEffect } from 'react'
import { useRef } from 'react'

/**
 * This hook is used to skip a pagination reset temporarily
 */
export function useSkipper() {
  const shouldSkipRef = useRef(true)
  const shouldSkip = shouldSkipRef.current

  const skip = useCallback(() => {
    shouldSkipRef.current = false
  }, [])

  useEffect(() => {
    shouldSkipRef.current = true
  })

  return [shouldSkip, skip] as const
}
