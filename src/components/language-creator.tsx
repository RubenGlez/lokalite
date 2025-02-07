'use client'

import { Button } from '~/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger
} from '~/components/ui/dialog'
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage
} from '~/components/ui/form'
import { zodResolver } from '@hookform/resolvers/zod'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import { api } from '~/trpc/react'
import { useState } from 'react'
import { useRouter } from 'next/navigation'

import { ChevronsUpDown, Check } from 'lucide-react'
import { cn } from '~/lib/utils'
import {
  Popover,
  PopoverContent,
  PopoverTrigger
} from '~/components/ui/popover'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList
} from '~/components/ui/command'

const formSchema = z.object({
  code: z.string().min(2, 'Language code must be at least 2 characters')
})

interface LanguageCreatorProps {
  children: React.ReactNode
  projectId: string
}

const commonLanguages = [
  { name: 'Mandarin Chinese', code: 'zh-CN' },
  { name: 'Spanish', code: 'es-ES' },
  { name: 'English', code: 'en-US' },
  { name: 'Hindi', code: 'hi-IN' },
  { name: 'Bengali', code: 'bn-BD' },
  { name: 'Portuguese', code: 'pt-BR' },
  { name: 'Russian', code: 'ru-RU' },
  { name: 'Japanese', code: 'ja-JP' },
  { name: 'Western Punjabi', code: 'pa-PK' },
  { name: 'Marathi', code: 'mr-IN' },
  { name: 'Telugu', code: 'te-IN' },
  { name: 'Wu Chinese (Shanghainese)', code: 'zh-CN-shanghainese' },
  { name: 'Turkish', code: 'tr-TR' },
  { name: 'Korean', code: 'ko-KR' },
  { name: 'French', code: 'fr-FR' },
  { name: 'German', code: 'de-DE' },
  { name: 'Vietnamese', code: 'vi-VN' },
  { name: 'Tamil', code: 'ta-IN' },
  { name: 'Urdu', code: 'ur-PK' },
  { name: 'Italian', code: 'it-IT' },
  { name: 'Yue Chinese (Cantonese)', code: 'zh-HK' },
  { name: 'Thai', code: 'th-TH' },
  { name: 'Gujarati', code: 'gu-IN' },
  { name: 'Javanese', code: 'jv-ID' },
  { name: 'Persian (Farsi)', code: 'fa-IR' },
  { name: 'Polish', code: 'pl-PL' },
  { name: 'Pashto', code: 'ps-AF' },
  { name: 'Kannada', code: 'kn-IN' },
  { name: 'Malayalam', code: 'ml-IN' },
  { name: 'Sundanese', code: 'su-ID' },
  { name: 'Hausa', code: 'ha-NG' },
  { name: 'Burmese', code: 'my-MM' },
  { name: 'Ukrainian', code: 'uk-UA' },
  { name: 'Hebrew', code: 'he-IL' },
  { name: 'Dutch', code: 'nl-NL' },
  { name: 'Romanian', code: 'ro-RO' },
  { name: 'Hakka Chinese', code: 'zh-TW-hakka' },
  { name: 'Tagalog (Filipino)', code: 'tl-PH' },
  { name: 'Hungarian', code: 'hu-HU' },
  { name: 'Greek', code: 'el-GR' }
]

export function LanguageCreator({ children, projectId }: LanguageCreatorProps) {
  const utils = api.useUtils()
  const router = useRouter()
  const [open, setOpen] = useState(false)
  const [isFirstLanguage, setIsFirstLanguage] = useState(false)
  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      code: ''
    }
  })
  const { data: existingLanguages, isLoading: isLoadingExistingLanguages } =
    api.languages.getByProject.useQuery({
      projectId
    })

  const updateProject = api.projects.update.useMutation({
    onSuccess: () => {
      utils.projects.invalidate()
      utils.languages.invalidate()
      router.refresh()
    }
  })

  const createLanguage = api.languages.create.useMutation({
    onMutate: () => {
      setIsFirstLanguage(existingLanguages?.length === 0)
    },
    onSuccess: (data) => {
      setOpen(false)
      form.reset()

      if (isFirstLanguage) {
        updateProject.mutate({
          id: projectId,
          defaultLanguageId: data?.id
        })
      } else {
        utils.languages.invalidate()
        router.refresh()
      }
    }
  })

  function onSubmit(values: z.infer<typeof formSchema>) {
    const selectedLanguage = commonLanguages.find(
      (lang) => lang.code === values.code
    )
    if (!selectedLanguage) return

    createLanguage.mutate({
      code: values.code,
      name: selectedLanguage.name,
      projectId
    })
  }

  const filteredCommonLanguages = commonLanguages.filter(
    (lang) => !existingLanguages?.some((l) => l.code === lang.code)
  )

  if (isLoadingExistingLanguages) return <div>Loading...</div>

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add Languages</DialogTitle>
          <DialogDescription>
            Add a new language to your project for translation.
          </DialogDescription>
        </DialogHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="code"
              render={({ field }) => (
                <FormItem className="flex flex-col">
                  <FormLabel className="sr-only">Languages</FormLabel>
                  <Popover>
                    <PopoverTrigger asChild>
                      <FormControl>
                        <Button
                          variant="outline"
                          role="combobox"
                          className={cn(
                            'justify-between',
                            !field.value && 'text-muted-foreground'
                          )}
                        >
                          {field.value
                            ? filteredCommonLanguages.find(
                                (language) => language.code === field.value
                              )?.name
                            : 'Select language'}
                          <ChevronsUpDown className="opacity-50" />
                        </Button>
                      </FormControl>
                    </PopoverTrigger>
                    <PopoverContent className="p-0" align="start">
                      <Command>
                        <CommandInput
                          placeholder="Search language..."
                          className="h-9"
                        />
                        <CommandList>
                          <CommandEmpty>No languages found.</CommandEmpty>
                          <CommandGroup>
                            {filteredCommonLanguages.map((language) => (
                              <CommandItem
                                value={language.code}
                                key={language.code}
                                onSelect={() => {
                                  form.setValue('code', language.code)
                                }}
                              >
                                {language.name}
                                <Check
                                  className={cn(
                                    'ml-auto',
                                    language.code === field.value
                                      ? 'opacity-100'
                                      : 'opacity-0'
                                  )}
                                />
                              </CommandItem>
                            ))}
                          </CommandGroup>
                        </CommandList>
                      </Command>
                    </PopoverContent>
                  </Popover>
                  <FormMessage />
                </FormItem>
              )}
            />

            <Button
              type="submit"
              className="w-full"
              disabled={createLanguage.isPending}
            >
              {createLanguage.isPending ? 'Adding...' : 'Add Language'}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}
