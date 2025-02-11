import { Textarea } from '~/components/ui/textarea'
import { Input } from '~/components/ui/input'
import { api } from '~/trpc/react'
import { useSelectedProject } from '~/hooks/use-selected-project'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage
} from '~/components/ui/form'
import { z } from 'zod'
import { useSelectedPage } from '~/hooks/use-selected-page'
import { useMemo } from 'react'

interface TranslationEditorFormProps {
  keyId: string
}

interface FormValues {
  key: string
  translations: Record<string, string>
}

const formSchema = z.object({
  key: z
    .string()
    .min(1)
    .regex(/^[a-zA-Z0-9_]+$/, {
      message: 'Key can only contain letters, numbers, and underscores'
    }),
  translations: z.record(z.string(), z.string().optional())
})

export function TranslationEditorForm({ keyId }: TranslationEditorFormProps) {
  const selectedProject = useSelectedProject()
  const selectedPage = useSelectedPage()
  const { data: languages } = api.languages.getByProject.useQuery(
    {
      projectId: selectedProject?.id ?? ''
    },
    {
      enabled: !!selectedProject?.id
    }
  )

  const { data: translationKey } = api.translationKeys.getById.useQuery(
    { id: keyId },
    { enabled: !!keyId }
  )
  const { data: translations } = api.translations.getByKeyId.useQuery(
    {
      pageId: selectedPage?.id ?? '',
      keyId
    },
    {
      enabled: !!keyId && !!selectedPage?.id
    }
  )

  const sourceLanguage = useMemo(
    () => languages?.find((language) => language.isSource),
    [languages]
  )

  const defaultValues = useMemo(() => {
    const translationsRecord: Record<string, string> = {}
    translations?.forEach((translation) => {
      translationsRecord[translation.languageCode] = translation.value
    })

    return {
      key: translationKey?.key ?? '',
      translations: translationsRecord
    }
  }, [translationKey, translations])

  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues,
    values: defaultValues
  })

  const handleSubmit = (values: FormValues) => {
    console.log('handleSubmit', values)
  }

  console.log('errors', form.formState.errors)

  return (
    <Form {...form}>
      <form
        onSubmit={form.handleSubmit(handleSubmit)}
        className="flex flex-col gap-6 py-8 px-[1px]"
      >
        <FormField
          control={form.control}
          name="key"
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
            name={`translations.${language.code}`}
            render={({ field }) => (
              <FormItem>
                <FormLabel>
                  {language.code === sourceLanguage?.code
                    ? `${language.name} (Source)`
                    : language.name}
                </FormLabel>
                <FormControl>
                  <Textarea placeholder="The translation value" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
        ))}
      </form>
    </Form>
  )
}
