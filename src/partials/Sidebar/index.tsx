import Text from "@/components/Text";
import TextInput from "@/components/TextInput";
import { SidebarProps } from "./types";
import TextArea from "@/components/TextArea";
import { XMarkIcon } from "@heroicons/react/24/outline";
import { useGetTranslation } from "@/hooks/useGetTranslation";
import { FormEvent, useEffect, useRef } from "react";
import Button from "@/components/Button";
import { useUpdateTranslation } from "@/hooks/useUpdateTranslation";
import { LANG_PREFIX, emptyArray } from "@/constants/global";
import Router from "next/router";
import { useTranslate } from "@/hooks/useTranslate";
import { Copies } from "@/lib/database.types";

export default function Sidebar({
  handleCloseSidebar,
  translationId,
  languages,
  defaultLanguage,
}: SidebarProps) {
  const successCallback = () => {
    handleCloseSidebar();
    // Todo avoid reload: Do the fetch instead
    Router.reload();
  };
  const { getTranslation, translation } = useGetTranslation({});
  const { updateTranslation } = useUpdateTranslation({ successCallback });
  const { data: translatedCopies, translate } = useTranslate({});
  const isVisible = Boolean(translationId && translation);
  const key = translation?.key ?? "";
  const copies = translation?.copies;
  const defaultLangCopy = useRef(copies?.[defaultLanguage ?? ""] ?? "");

  const handleUpdateTranslation = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const formJson = Object.fromEntries(formData.entries());
    const copies = Object.keys(formJson).reduce(
      (acc: Record<string, string>, curr) => {
        if (curr.startsWith(LANG_PREFIX)) {
          const lang = curr.replace(LANG_PREFIX, "");
          acc[lang] = String(formJson[curr]);
        }
        return acc;
      },
      {}
    );
    updateTranslation({
      id: translation.id,
      sheet_id: translation.sheet_id,
      key: String(formJson.key),
      copies: {
        ...copies,
        ...(defaultLanguage
          ? { [defaultLanguage as keyof Copies]: formJson[defaultLanguage] }
          : {}),
      },
    });
  };

  const handleTranslate = () => {
    translate({
      copy: defaultLangCopy.current,
      inputLang: defaultLanguage ?? "",
      languages: languages ?? emptyArray,
    });
  };

  const handleChange = (val?: string) => {
    defaultLangCopy.current = val ?? "";
  };

  useEffect(() => {
    if (translationId) {
      getTranslation(translationId);
    }
  }, [getTranslation, translationId]);

  if (!isVisible) return <></>;

  return (
    <div className="fixed top-0 right-0 bottom-0 w-1/2 z-40 bg-slate-900">
      <form onSubmit={handleUpdateTranslation} className="flex flex-col h-full">
        <div className="flex flex-row justify-between p-4">
          <Text as="p" size="xs" color="secondary">
            {"EDITAR FILA"}
          </Text>
          <XMarkIcon
            className="h-6 w-6 text-slate-100 cursor-pointer"
            onClick={handleCloseSidebar}
          />
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          {key && (
            <div className="mb-6">
              <TextInput name="key" label={"key"} defaultValue={key} />
            </div>
          )}

          <div className="mb-6">
            <TextArea
              name={defaultLanguage ?? ""}
              key={defaultLanguage}
              label={`${defaultLanguage} (default)`}
              defaultValue={copies?.[defaultLanguage ?? ""]}
              className="mb-3"
              handleChange={handleChange}
            />
            <Button
              text="Traducir"
              template="primary"
              onClick={handleTranslate}
            />
          </div>

          {languages?.map((lang) => {
            return (
              <div key={lang} className="mb-6">
                <TextArea
                  name={`${LANG_PREFIX}${lang}`}
                  label={lang}
                  defaultValue={copies?.[lang]}
                  value={translatedCopies?.[lang as any]}
                />
              </div>
            );
          })}
        </div>

        <div className="flex flex-row justify-between p-4">
          <Button text="Guardar" type="submit" />
          <Button
            text="Cancelar"
            template="secondary"
            onClick={handleCloseSidebar}
          />
        </div>
      </form>
    </div>
  );
}
