import { Textarea } from '~/components/ui/textarea'
import { Input } from '~/components/ui/input'
import { api } from '~/trpc/react'
import { useSelectedProject } from '~/hooks/use-selected-project'
import { UseFormReturn } from 'react-hook-form'
import {
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage
} from '~/components/ui/form'
import { FormValues } from './schema'

interface TranslationsRowFormProps {
  keyId: string
  form: UseFormReturn<FormValues>
}

export function TranslationsRowForm({ keyId, form }: TranslationsRowFormProps) {
  const selectedProject = useSelectedProject()
  const { data: languages } = api.languages.getByProject.useQuery(
    {
      projectId: selectedProject?.id ?? ''
    },
    {
      enabled: !!selectedProject?.id
    }
  )

  return (
    <div className="flex flex-col gap-6 py-8 px-[1px]">
      <FormField
        control={form.control}
        name={`keys.${keyId}.key`}
        render={({ field }) => (
          <FormItem>
            <FormLabel>Key</FormLabel>
            <FormControl>
              <Input placeholder="The translation key" {...field} />
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />

      {languages?.map((language) => (
        <FormField
          key={language.id}
          control={form.control}
          name={`keys.${keyId}.translations.${language.code}`}
          render={({ field }) => (
            <FormItem>
              <FormLabel>
                {language.isSource
                  ? `${language.name} (Source)`
                  : language.name}
              </FormLabel>
              <FormControl>
                <Textarea
                  placeholder="Type the translation here..."
                  {...field}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
      ))}
    </div>
  )
}
