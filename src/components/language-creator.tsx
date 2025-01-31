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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from '~/components/ui/select'
import { useRouter } from 'next/navigation'

const formSchema = z.object({
  code: z.string().length(2, 'Language code must be exactly 2 characters')
})

interface LanguageCreatorProps {
  children: React.ReactNode
  projectId: string
}

const commonLanguages = [
  { code: 'en', name: 'English' },
  { code: 'es', name: 'Spanish' },
  { code: 'zh', name: 'Chinese' },
  { code: 'hi', name: 'Hindi' },
  { code: 'ar', name: 'Arabic' },
  { code: 'fr', name: 'French' },
  { code: 'bn', name: 'Bengali' },
  { code: 'ru', name: 'Russian' },
  { code: 'pt', name: 'Portuguese' },
  { code: 'ur', name: 'Urdu' },
  { code: 'id', name: 'Indonesian' },
  { code: 'de', name: 'German' },
  { code: 'ja', name: 'Japanese' },
  { code: 'sw', name: 'Swahili' },
  { code: 'tr', name: 'Turkish' },
  { code: 'ta', name: 'Tamil' },
  { code: 'ko', name: 'Korean' },
  { code: 'vi', name: 'Vietnamese' },
  { code: 'it', name: 'Italian' },
  { code: 'th', name: 'Thai' }
] as const

export function LanguageCreator({ children, projectId }: LanguageCreatorProps) {
  const utils = api.useUtils()
  const router = useRouter()
  const [open, setOpen] = useState(false)
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

  const createLanguage = api.languages.create.useMutation({
    onSuccess: () => {
      setOpen(false)
      form.reset()
      utils.languages.getByProject.invalidate()
      router.refresh()
    }
  })

  function onSubmit(values: z.infer<typeof formSchema>) {
    const selectedLanguage = commonLanguages.find(
      (lang) => lang.code === values.code.toLowerCase()
    )
    if (!selectedLanguage) return

    createLanguage.mutate({
      code: values.code.toLowerCase(),
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
          <DialogTitle>Add Language</DialogTitle>
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
                <FormItem>
                  <FormLabel>Language</FormLabel>
                  <Select
                    onValueChange={field.onChange}
                    defaultValue={field.value}
                  >
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select a language" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {filteredCommonLanguages.map((lang) => (
                        <SelectItem key={lang.code} value={lang.code}>
                          {lang.name} ({lang.code})
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
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
