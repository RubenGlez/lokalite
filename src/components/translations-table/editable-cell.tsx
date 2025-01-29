import { CellContext } from '@tanstack/react-table'
import { useEffect, useState } from 'react'

import { ComposedTranslation } from '~/server/db/types'
import { Input } from '../ui/input'

export function EditableCell({
  getValue,
  row,
  column,
  table
}: CellContext<ComposedTranslation, unknown>) {
  const initialValue = (getValue() as string) ?? ''
  // We need to keep and update the state of the cell normally
  const [value, setValue] = useState(initialValue)

  // When the input is blurred, we'll call our table meta's updateData function
  const onBlur = () => {
    table.options.meta?.updateCell(row.original.id, column.id, value)
  }

  // If the initialValue is changed external, sync it up with our state
  useEffect(() => {
    setValue(initialValue)
  }, [initialValue])

  return (
    <Input
      value={value}
      onChange={(e) => setValue(e.target.value)}
      onBlur={onBlur}
    />
  )
}
