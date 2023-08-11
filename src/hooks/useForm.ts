import { useState } from "react";

type FormValue = string | number | boolean | undefined;
interface UseFormProps {
  initialState: Record<string, FormValue>;
}

export const useForm = ({ initialState }: UseFormProps) => {
  const [formData, setFormData] = useState(initialState);

  const setFieldValue = (field: string, value: FormValue) => {
    setFormData((prev) => ({
      ...prev,
      [field]: value,
    }));
  };

  return {
    values: formData,
    setFieldValue,
  };
};
