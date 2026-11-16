import * as React from "react";
import { useForm, FieldErrors } from "react-hook-form";
import z from "zod";
import { zodResolver } from "@hookform/resolvers/zod";

const formSchema = z.object({
  title: z.string().min(1, { error: "Title is required" }),
});
type STFormSchema = z.infer<typeof formSchema>;
export const DemoComponent = (): JSX.Element => {
  const formLogic = useForm<STFormSchema>({
    resolver: zodResolver(formSchema),
  });

  const submit = (data: STFormSchema): void => {
    console.log(data);
  };

  const onFail = (Errors: FieldErrors<STFormSchema>): void => {
    console.log(Errors);
  };

  return (
    <form onSubmit={formLogic.handleSubmit(submit, onFail)}>
      <label>Title</label>
      <input type="text" {...formLogic.register("title")} />
      {formLogic.formState.errors.title && formLogic.formState.errors.title && (
        <p>{formLogic.formState.errors.title.message}</p>
      )}
      <button type="submit">Submit</button>
    </form>
  );
};
