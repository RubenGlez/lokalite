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
import { Input } from '~/components/ui/input'
import { zodResolver } from '@hookform/resolvers/zod'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import { api } from '~/trpc/react'
import { useState } from 'react'
import { useRouter } from 'next/navigation'

const formSchema = z.object({
  name: z.string().min(1, 'Page name is required'),
  slug: z
    .string()
    .min(1, 'Slug is required')
    .regex(/^[a-z0-9-]+$/, {
      message: 'Slug can only contain lowercase letters, numbers, and hyphens'
    }),
  projectId: z.string().min(1, 'Project ID is required')
})

interface PageCreatorProps {
  projectId: string
  children: React.ReactNode
}

export function PageCreator({ projectId, children }: PageCreatorProps) {
  const [open, setOpen] = useState(false)
  const router = useRouter()

  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      name: '',
      slug: '',
      projectId
    }
  })

  const createPage = api.pages.create.useMutation({
    onSuccess: () => {
      setOpen(false)
      form.reset()
      router.refresh()
    }
  })

  function onSubmit(values: z.infer<typeof formSchema>) {
    console.log('Submitting form with values:', values)
    createPage.mutate(values)
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Create Page</DialogTitle>
          <DialogDescription>
            Create a new page to organize your translations.
          </DialogDescription>
        </DialogHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Page Name</FormLabel>
                  <FormControl>
                    <Input placeholder="Home Page" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="slug"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Page Slug</FormLabel>
                  <FormControl>
                    <Input placeholder="home" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <Button
              type="submit"
              className="w-full"
              disabled={createPage.isPending}
            >
              {createPage.isPending ? 'Creating...' : 'Create Page'}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}
