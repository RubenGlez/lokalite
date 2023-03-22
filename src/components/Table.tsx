import { ChangeEventHandler } from "react";
import TableCell from "./TableCell";
import TableHeaderCell from "./TableHeaderCell";
import TableRow from "./TableRow";

interface Cell {
  value: string;
}

interface Row {
  cells: Cell[];
}

interface Table {
  headerCells: {
    label: string;
  }[];
  rows: Row[];
  onChange: ChangeEventHandler<HTMLInputElement>;
}

export default function Table({ headerCells, rows, onChange }: Table) {
  return (
    <div className="overflow-x-auto pb-4">
      <table className="table-auto border-collapse">
        <thead>
          <TableRow key={`tableHeaderRow_0`}>
            {headerCells.map((headerCell, index) => (
              <TableHeaderCell key={`tableHeaderCell_${index}`} index={index}>
                {headerCell.label}
              </TableHeaderCell>
            ))}
          </TableRow>
        </thead>
        <tbody>
          {rows.map((row, rowIndex) => (
            <TableRow key={`tableRow_${rowIndex}`}>
              {row.cells.map((cell, cellIndex) => (
                <TableCell
                  key={`tableCell_${cellIndex}`}
                  index={cellIndex}
                  value={cell.value}
                  onChange={onChange}
                />
              ))}
            </TableRow>
          ))}
        </tbody>
      </table>
    </div>
  );
}
