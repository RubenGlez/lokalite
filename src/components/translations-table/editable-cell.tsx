import { memo, useCallback, useState } from 'react'

import { Input } from '../ui/input'

interface EditableCellProps {
  onUpdateCell: (value: string) => void
  initialValue: string
}

export function EditableCell({
  onUpdateCell,
  initialValue
}: EditableCellProps) {
  const [value, setValue] = useState(initialValue)

  const onBlur = useCallback(() => {
    if (value === initialValue) return

    onUpdateCell(value)
  }, [onUpdateCell, value, initialValue])

  const onChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    setValue(e.target.value)
  }, [])

  return (
    <Input
      value={value}
      onChange={onChange}
      onBlur={onBlur}
      className="border-none shadow-none truncate rounded-none focus-visible:ring-1 focus-visible:ring-inset min-h-10"
    />
  )
}

export const MemoizedEditableCell = memo(EditableCell)
