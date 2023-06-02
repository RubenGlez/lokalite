import Text from "@/components/Text";
import TextInput from "@/components/TextInput";
import { SidebarProps } from "./types";
import TextArea from "@/components/TextArea";
import { XMarkIcon } from "@heroicons/react/24/outline";
import { useGetTranslation } from "@/hooks/useGetTranslation";
import { useEffect } from "react";
import Button from "@/components/Button";

export default function Sidebar({
  handleCloseSidebar,
  translationId,
  languages,
  defaultLanguage,
}: SidebarProps) {
  const { getTranslation, isLoading, translation } = useGetTranslation({});
  const isVisible = Boolean(translationId && translation);
  const key = translation?.key;
  const copies = translation?.copies;

  useEffect(() => {
    if (translationId) {
      getTranslation(translationId);
    }
  }, [getTranslation, translationId]);

  return isVisible ? (
    <div className="absolute top-0 right-0 bottom-0 w-1/2 z-40 bg-slate-900 h-full">
      <div className="flex flex-col flex-1">
        <div className="flex items-center justify-between mb-6">
          <Text as="p" size="xs" color="secondary">
            {"EDITAR FILA"}
          </Text>
          <XMarkIcon
            className="h-6 w-6 text-slate-100 cursor-pointer"
            onClick={handleCloseSidebar}
          />
        </div>

        <div className="flex flex-col overflow-auto">
          {key && (
            <div className="mb-6">
              <TextInput label={"key"} defaultValue={key} />
            </div>
          )}

          <div className="mb-6">
            <TextArea
              key={defaultLanguage}
              label={`${defaultLanguage} (default)`}
              defaultValue={copies?.[defaultLanguage ?? ""]}
            />
          </div>

          {languages?.map((lang) => {
            return (
              <div key={key} className="mb-6">
                <TextArea label={lang} defaultValue={copies?.[lang]} />
              </div>
            );
          })}
          {languages?.map((lang) => {
            return (
              <div key={key} className="mb-6">
                <TextArea label={lang} defaultValue={copies?.[lang]} />
              </div>
            );
          })}
          {languages?.map((lang) => {
            return (
              <div key={key} className="mb-6">
                <TextArea label={lang} defaultValue={copies?.[lang]} />
              </div>
            );
          })}
        </div>

        <div className="flex items-center justify-between">
          <Button text="adfasdf" />
          <Button text="adfasdf" />
          <Button text="adfasdf" />
        </div>
      </div>
    </div>
  ) : (
    <></>
  );
}
