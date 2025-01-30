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

  return <Input value={value} onChange={onChange} onBlur={onBlur} />
}

export const MemoizedEditableCell = memo(EditableCell)
