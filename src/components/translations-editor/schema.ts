import { z } from 'zod'

export const formSchema = z.object({
  keys: z.record(
    z.string(),
    z.object({
      key: z
        .string()
        .min(1)
        .regex(/^[a-zA-Z0-9_]+$/, {
          message: 'Key can only contain letters, numbers, and underscores'
        }),
      translations: z.record(z.string(), z.string().optional())
    })
  )
})

export type FormValues = z.infer<typeof formSchema>
