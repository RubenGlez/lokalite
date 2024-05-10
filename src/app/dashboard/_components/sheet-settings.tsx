import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";
import { Settings } from "lucide-react";

const options = [
  {
    id: "1",
    label: "Configuration",
    onClick: () => {},
  },
  {
    id: "2",
    label: "Configuration",
    onClick: () => {},
  },
  {
    id: "3",
    label: "Configuration",
    onClick: () => {},
  },
];

export default function SheetSettings() {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline">
          <Settings className="mr-2 h-4 w-4" />
          Settings
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-[150px]">
        {options.map(({ id, label }) => (
          <DropdownMenuItem key={id}>
            <Settings className="mr-2 h-4 w-4" />
            {label}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
