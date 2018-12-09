import requests

from psycopg2 import sql, connect, DatabaseError


ZIP_DATABASE_NAME = 'postgres'
ZIP_DATABASE_USER = 'postgres'
ZIP_DATABASE_PASSWORD = 'system'


def zip_detail_api():

    try:
        conn = connect(dbname=ZIP_DATABASE_NAME, user=ZIP_DATABASE_USER, password=ZIP_DATABASE_PASSWORD)
        conn.autocommit = True
    except DatabaseError as e:
        print("You've got Database Error" + e.pgerror)

    cur_insert = conn.cursor()
    cur_select = conn.cursor()
    cur_trunc = conn.cursor()

    cur_trunc.execute("truncate zip")
    cur_select.execute("select zipcode from \"order\"")
    rows = cur_select.fetchall()

    for row in rows:
        zip = row[0]
        url = 'http://www.zipcodeapi.com/rest/TzJKeXqhni0HWzxQcbPmG94QHKfdZOj2ZTwumlokhsPAaB1Mp5NN1ByhCZrM5jrz/info.json/{}/degrees'.format(zip)

        try:
            response = requests.get(url=url, timeout=(1, 10)).json()
            cur_insert.execute(
                sql.SQL("insert into {} values (%s, %s, %s, %s, %s)").format(sql.Identifier('zip')),
                [response["zip_code"], response["lat"], response["lng"], response["city"], response["state"]])
        except TimeoutError:
            print('Connection occured')

    conn.commit()


if __name__ == '__main__':
    zip_detail_api()
