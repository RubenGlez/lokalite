import { useFetch } from "@/hooks/useFetch";
import { Sheet } from "@/pages/api/sheet";
import { ChangeEventHandler } from "react";
import TableCell from "./TableCell";
import TableHeaderCell from "./TableHeaderCell";
import TableRow from "./TableRow";
import Text from "@/components/Text";
import { BookmarkIcon } from "@heroicons/react/24/outline";

interface HeaderCell {
  label: string;
  isDefault?: boolean;
}

interface Table {
  headerCells: HeaderCell[];
  onChange: ChangeEventHandler<HTMLInputElement>;
  sheetId: string;
}

export default function Table({ headerCells, onChange, sheetId }: Table) {
  const { data, isLoading } = useFetch<Sheet>(`/api/sheet/${sheetId}`);
  const rows = data?.locales || [];

  if (isLoading) {
    return <Text>Loading...</Text>;
  }

  return (
    <table className="table-auto">
      <thead>
        <TableRow key={`tableHeaderRow_0`}>
          {headerCells.map((headerCell, index) => (
            <TableHeaderCell key={`tableHeaderCell_${index}`}>
              <div className="flex items-center gap-2">
                {headerCell.isDefault && (
                  <BookmarkIcon
                    className="h-3 w-3 text-slate-300"
                    aria-hidden="true"
                  />
                )}
                {headerCell.label}
              </div>
            </TableHeaderCell>
          ))}
        </TableRow>
      </thead>
      <tbody>
        {rows.map((row, rowIdx) => (
          <TableRow key={`tableRow_${rowIdx}`}>
            {headerCells.map((col, colIdx) => {
              return (
                <TableCell
                  key={`tableCell_row_${rowIdx}_col${colIdx}`}
                  value={row[col.label]}
                  onChange={onChange}
                />
              );
            })}
          </TableRow>
        ))}
      </tbody>
    </table>
  );
}
