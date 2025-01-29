import { CellContext } from '@tanstack/react-table'
import { useEffect, useState } from 'react'

import { ComposedTranslation } from '~/server/db/types'

export function EditableCell({
  getValue,
  row: { index },
  column: { id },
  table
}: CellContext<ComposedTranslation, unknown>) {
  const initialValue = getValue()
  // We need to keep and update the state of the cell normally
  const [value, setValue] = useState(initialValue)

  // When the input is blurred, we'll call our table meta's updateData function
  const onBlur = () => {
    table.options.meta?.updateCell(index, id, value as string)
  }

  // If the initialValue is changed external, sync it up with our state
  useEffect(() => {
    setValue(initialValue)
  }, [initialValue])

  return (
    <input
      value={value as string}
      onChange={(e) => setValue(e.target.value)}
      onBlur={onBlur}
    />
  )
}
