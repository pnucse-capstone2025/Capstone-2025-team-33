# # python manage.py import_clothes user1

# import csv
# import os
# from django.core.management.base import BaseCommand
# from django.core.files import File
# from django.conf import settings
# from api.models import Clothes, CustomUser


# class Command(BaseCommand):
#     help = "Import clothes from CSV and assign to a specific user"

#     def add_arguments(self, parser):
#         # 実行例: python manage.py import_clothes user1
#         parser.add_argument("username", type=str, help="Target username")

#     def handle(self, *args, **kwargs):
#         username = kwargs["username"]

#         # 指定ユーザー取得
#         try:
#             user = CustomUser.objects.get(username=username)
#         except CustomUser.DoesNotExist:
#             self.stderr.write(self.style.ERROR(f"User '{username}' does not exist"))
#             return




#         # CSV 読み込み & Clothes 登録
#         with open("test_scenarios/Sheet 11-Autobahn.csv", newline="", encoding="utf-8") as csvfile:
#             reader = csv.DictReader(csvfile)
#             for row in reader:
#                 clothes = Clothes(
#                     owner=user,
#                     gender=row["gender"],
#                     masterCategory=row["masterCategory"],
#                     subCategory=row["subCategory"],
#                     articleType=row["articleType"],
#                     baseColor=row["baseColour"],   # ★ 注意: CSVの列名は baseColour
#                     season=row["season"],
#                     usage=row["usage"],
#                 )

#                 # 画像があれば保存
#                 image_name = row.get("Image")
#                 if image_name:
#                     image_path = os.path.join(settings.MEDIA_ROOT, "clothes", image_name)
#                     if os.path.exists(image_path):
#                         with open(image_path, "rb") as f:
#                             clothes.image.save(image_name, File(f), save=False)
#                         print(f"image saved: {image_name}")
#                     else:
#                         print(f"image not found: {image_path}")
#                 else:
#                     print("image column is empty")

#                 clothes.save()

#         self.stdout.write(self.style.SUCCESS(
#             f"Clothes imported successfully for user '{username}'"
#         ))


import csv
import os
from django.core.management.base import BaseCommand
from django.core.files import File
from django.conf import settings
from api.models import Clothes, CustomUser


class Command(BaseCommand):
    help = "Import clothes from CSV and assign to a specific user"

    def add_arguments(self, parser):
        # 実行例: python manage.py import_clothes user1
        parser.add_argument("username", type=str, help="Target username")

    def handle(self, *args, **kwargs):
        username = kwargs["username"]

        # 指定ユーザー取得
        try:
            user = CustomUser.objects.get(username=username)
        except CustomUser.DoesNotExist:
            self.stderr.write(self.style.ERROR(f"User '{username}' does not exist"))
            return

        # CSV 読み込み & Clothes 登録
        with open("test_scenarios/Sheet 12-Apfel.csv", newline="", encoding="utf-8") as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                clothes = Clothes(
                    owner=user,
                    gender=row["gender"],
                    masterCategory=row["masterCategory"],
                    subCategory=row["subCategory"],
                    articleType=row["articleType"],
                    baseColor=row["baseColour"],   # CSVの列名は baseColour
                    season=row["season"],
                    usage=row["usage"],
                )

                # 画像があれば保存
                image_name = row.get("Image")
                if image_name:
                    # 余分なsuffixを削除して正規化
                    base, ext = os.path.splitext(image_name.strip())
                    normalized_name = "_".join(base.split("_")[0:3]) + ext

                    image_path = os.path.join(settings.MEDIA_ROOT, "clothes", normalized_name)
                    if os.path.exists(image_path):
                        with open(image_path, "rb") as f:
                            clothes.image.save(normalized_name, File(f), save=False)
                        print(f"image saved: {normalized_name}")
                    else:
                        print(f"image not found: {image_path}")
                else:
                    print("image column is empty")

                clothes.save()

        self.stdout.write(self.style.SUCCESS(
            f"Clothes imported successfully for user '{username}'"
        ))
