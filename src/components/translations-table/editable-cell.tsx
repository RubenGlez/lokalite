import { ChangeEvent, memo, useCallback, useState } from 'react'

import { Input } from '../ui/input'

interface EditableCellProps {
  onUpdateCell: (value: string) => void
  initialValue: string
  isKeyCell?: boolean
}

export function EditableCell({
  onUpdateCell,
  initialValue,
  isKeyCell = false
}: EditableCellProps) {
  const [value, setValue] = useState(initialValue)

  const onBlur = useCallback(() => {
    if (value === initialValue) return

    onUpdateCell(value)
  }, [onUpdateCell, value, initialValue])

  const onChange = useCallback(
    (e: ChangeEvent<HTMLInputElement>) => {
      if (isKeyCell) {
        const sanitizedValue = e.target.value
          .replace(/ /g, '_')
          .replace(/[^a-zA-Z0-9_]/g, '')
        setValue(sanitizedValue)
      } else {
        setValue(e.target.value)
      }
    },
    [isKeyCell]
  )

  return (
    <Input
      value={value}
      onChange={onChange}
      onBlur={onBlur}
      className="truncate border-transparent shadow-transparent focus-visible:border-input focus-visible:shadow-sm"
    />
  )
}

export const MemoizedEditableCell = memo(EditableCell)
