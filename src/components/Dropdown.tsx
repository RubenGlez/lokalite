import { Menu, Transition } from "@headlessui/react";
import { Fragment } from "react";
import { ChevronDownIcon } from "@heroicons/react/24/outline";
import { cls } from "@/utils";

interface Item {
  label: string;
  Icon: typeof ChevronDownIcon;
  onClick: () => void;
}

interface DropdownProps {
  items: Item[];
  placeholder: string;
  className?: string;
}

export default function Dropdown({
  items = [],
  placeholder = "Options",
  className,
}: DropdownProps) {
  return (
    <div className={className}>
      <Menu as="div" className="relative inline-block text-left">
        <div>
          <Menu.Button className="flex items-center gap-x-2 border border-slate-700 rounded-md bg-slate-900 py-2 px-3 focus:outline-none focus:border-slate-100">
            <span className="block truncate text-left text-sm text-slate-400">
              {placeholder}
            </span>
            <ChevronDownIcon
              className="h-3 w-3 text-slate-400"
              aria-hidden="true"
            />
          </Menu.Button>
        </div>
        <Transition
          as={Fragment}
          enter="transition ease-out duration-100"
          enterFrom="transform opacity-0 scale-95"
          enterTo="transform opacity-100 scale-100"
          leave="transition ease-in duration-75"
          leaveFrom="transform opacity-100 scale-100"
          leaveTo="transform opacity-0 scale-95"
        >
          <Menu.Items className="absolute right-0 mt-1 w-36 origin-top-right rounded-md bg-slate-900 border border-slate-700 py-1 z-50">
            {items.map((item, index) => (
              <Menu.Item key={`menu_item_${index}`}>
                {({ active }) => (
                  <button
                    className={cls({
                      "flex w-full items-center gap-x-2 py-2 px-3": true,
                      "text-slate-400": !active,
                      "text-slate-100 bg-slate-800": active,
                    })}
                    onClick={item.onClick}
                  >
                    <item.Icon className="h-4 w-4" aria-hidden="true" />
                    <span className="block truncate text-left text-sm">
                      {item.label}
                    </span>
                  </button>
                )}
              </Menu.Item>
            ))}
          </Menu.Items>
        </Transition>
      </Menu>
    </div>
  );
}
